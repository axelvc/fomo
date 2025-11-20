//
//  BlockController.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import DeviceActivity
import FamilyControls
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
            repeats: item.repeatOn
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
        
        self._repeatLimit(
            activity: activityName,
            storage: storage,
            center: center
        )
    }
    
    fileprivate func _repeatLimit(activity: DeviceActivityName, storage: LimitStorage, center: DeviceActivityCenter) {
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

nonisolated class FomoActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        Task { @MainActor in
            let rawKey = activity.rawValue
            
            guard activity.blockModeFromName == .schedule else { return }
            
            guard
                let data = SharedDefaults.shared.data(forKey: rawKey),
                let tokens = try? JSONDecoder().decode(
                    [ApplicationToken].self,
                    from: data
                )
            else {
                return
            }

            BlockController.shared.applyBlock(for: Set(tokens))
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        Task { @MainActor in
            guard activity.blockModeFromName == .schedule else { return }

            BlockController.shared.clearBlock()
            SharedDefaults.shared.removeObject(forKey: activity.rawValue)
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard event.rawValue == "limitReached" else { return }

        Task { @MainActor in
            let rawKey = activity.rawValue

            guard
                let data = SharedDefaults.shared.data(forKey: rawKey),
                let storage = try? JSONDecoder().decode(
                    LimitStorage.self,
                    from: data
                )
            else { return }

            let center = DeviceActivityCenter()

            center.stopMonitoring([activity])

            let tokens = Set(storage.tokens)
            BlockController.shared.applyBlock(for: tokens)

            try? await Task.sleep(for: .seconds(storage.breakSeconds))

            BlockController.shared.clearBlock()
            BlockController.shared._repeatLimit(
                activity: activity,
                storage: storage,
                center: center
            )
        }
    }
}
