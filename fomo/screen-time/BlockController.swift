//
//  BlockController.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import DeviceActivity
import Foundation
import ManagedSettings
import FamilyControls

extension DeviceActivityName {
    init(for item: ItemProtocol) {
        self.init("fomo.\(item.id.uuidString)")
    }
}

nonisolated let limitReachedEvent = DeviceActivityEvent.Name("limitReached")

@MainActor
final class BlockController {
    static let shared = BlockController()

    private func store(for item: ItemProtocol) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(item.id.uuidString))
    }

    private func saveItem(_ item: ItemProtocol) {
        let activityName = DeviceActivityName(for: item)
        let config = ItemConfig(from: item)

        if let data = try? JSONEncoder().encode(config) {
            SharedDefaults.shared.set(data, forKey: activityName.rawValue)
        }
    }

    func startMonitoring(for item: Item) {
        saveItem(item)

        switch item.blockMode {
        case .timer, .schedule:
            // Block during window
            try? createScheduled(
                for: item,
                start: item.scheduleWindow.start,
                end: item.scheduleWindow.end
            )
        case .limit:
            // Monitor usage, block when limit reached
            createThreshold(for: item, threshold: item.limitConfig.freeTime)
        case .opens:
            // Block immediately (forever/until used)
            applyShield(for: item)
        }
    }

    func stopMonitoring(for item: Item) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        center.stopMonitoring([activityName])

        // Clear shield
        let store = store(for: item)
        store.clearAllSettings()

        // Clean up defaults
        SharedDefaults.shared.removeObject(forKey: activityName.rawValue)
    }

    func useOpen(for item: ItemProtocol) {
        guard item.blockMode == .opens, item.opensConfig.opensLeft > 0 else { return }
        var item = item

        item.opensConfig.opensLeft -= 1
        saveItem(item)
        clearShield(for: item)
        createThreshold(for: item, threshold: TimeInterval(minutes: item.opensConfig.allowedPerOpen))
    }

    private func saveConfig(_ config: ItemConfig) {
        let activityName = DeviceActivityName(for: config)
        if let data = try? JSONEncoder().encode(config) {
            SharedDefaults.shared.set(data, forKey: activityName.rawValue)
        }
    }

    func applyShield(for item: ItemProtocol) {
        let store = store(for: item)
        store.shield.applications = item.activitySelection.applicationTokens
    }

    func clearShield(for item: ItemProtocol) {
        let store = store(for: item)
        store.clearAllSettings()
    }

    func createScheduled(for item: ItemProtocol, start: Date, end: Date) throws {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        let startComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: start
        )
        let endComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: end
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true
        )

        try center.startMonitoring(
            activityName,
            during: schedule
        )
    }

    func createThreshold(for item: ItemProtocol, threshold: TimeInterval) {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(for: item)

        let startComponents = DateComponents(hour: 0, minute: 0)
        let endComponents = DateComponents(hour: 23, minute: 59)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true
        )

        let thresholdComponents = DateComponents(second: Int(threshold))
        let limitEvent = DeviceActivityEvent(
            applications: item.activitySelection.applicationTokens,
            threshold: thresholdComponents
        )

        do {
            try center.startMonitoring(
                activityName,
                during: schedule,
                events: [limitReachedEvent: limitEvent]
            )
        } catch {
            print("Failed to start limit monitoring:", error)
        }
    }
}
