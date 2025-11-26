//
//  BlockController.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import DeviceActivity
import Foundation
import ManagedSettings

enum SharedDefaults {
    static let suiteName = "group.axelvc.fomo"
    static var shared: UserDefaults { .init(suiteName: suiteName)! }
}

extension DeviceActivityName {
    init(for item: Item) {
        self.init("fomo.\(item.blockMode).\(item.id.uuidString)")
    }

    var blockModeFromName: BlockMode? {
        let parts = rawValue.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        return BlockMode(rawValue: String(parts[1]))
    }
}

struct LimitStorage: Codable {
    let tokens: [ApplicationToken]
    let freeSeconds: Int
    let breakSeconds: Int
}

@MainActor
final class BlockController {
    static let shared = BlockController()
    private let store = ManagedSettingsStore()

    func applyBlock(for tokens: Set<ApplicationToken>) {
        let apps = Set(tokens.map(Application.init))
        self.applyBlock(for: apps)
    }

    func applyBlock(for apps: Set<Application>) {
        store.application.blockedApplications = apps.isEmpty ? nil : .init(apps)
    }

    func clearBlock() {
        store.clearAllSettings()
    }

    func startMonitoring(for item: Item) {
        switch item.blockMode {
        case .timer:
            item.scheduleWindow = .init(of: item.timerDuration)
            try? startSchedule(for: item)
        case .schedule:
            try? startSchedule(for: item)
        case .limit:
            startLimit(for: item)
        case .opens:
            // TODO
            break
        }
    }

    func stopMonitoring(for item: Item) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        center.stopMonitoring([activityName])
    }

    func startSchedule(for item: Item) throws {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        let tokensArray = Array(item.apps)
        if let data = try? JSONEncoder().encode(tokensArray) {
            SharedDefaults.shared.set(data, forKey: activityName.rawValue)
        }

        let startComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: item.scheduleWindow.start
        )
        let endComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: item.scheduleWindow.end
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        try center.startMonitoring(
            activityName,
            during: schedule
        )
    }

    func startLimit(for item: Item) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        let freeSeconds = item.limitConfig.freeTime.totalSeconds
        let breakSeconds = item.limitConfig.breakTime.totalSeconds

        let storage = LimitStorage(
            tokens: Array(item.apps),
            freeSeconds: freeSeconds,
            breakSeconds: breakSeconds
        )

        if let data = try? JSONEncoder().encode(storage) {
            SharedDefaults.shared.set(data, forKey: activityName.rawValue)
        }

        self.repeatLimit(
            activity: activityName,
            storage: storage,
            center: center
        )
    }

    func repeatLimit(
        activity: DeviceActivityName, storage: LimitStorage, center: DeviceActivityCenter
    ) {
        let startComponents = DateComponents(hour: 0, minute: 0)
        let endComponents = DateComponents(hour: 23, minute: 59)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true
        )

        let thresholdComponents = DateComponents(second: storage.freeSeconds)
        let limitEventName = DeviceActivityEvent.Name("limitReached")
        let limitEvent = DeviceActivityEvent(
            applications: Set(storage.tokens),
            threshold: thresholdComponents
        )

        do {
            try center.startMonitoring(
                activity,
                during: schedule,
                events: [limitEventName: limitEvent]
            )
        } catch {
            print("Failed to start limit monitoring:", error)
        }
    }
}
