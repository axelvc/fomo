//
//  ActivityMonitor.swift
//  fomo
//
//  Created by Axel on 22/11/25.
//

import DeviceActivity
import Foundation
import ManagedSettings

nonisolated class ActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        Task { @MainActor in
            handleScheduledStart(activity: activity)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        Task { @MainActor in
            handleScheduledEnd(activity: activity)
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard event == limitReachedEvent else { return }

        Task { @MainActor in
            guard let config = retrieveConfig(for: activity) else { return }

            switch config.blockMode {
            case .limit:
                handleLimitBlock(activity: activity, config: config)
            case .opens:
                handleOpensBlock(activity: activity, config: config)
            default:
                break
            }
        }
    }
}

extension ActivityMonitor {
    func retrieveConfig(for activity: DeviceActivityName) -> ItemConfig? {
        guard let data = SharedDefaults.shared.data(forKey: activity.rawValue) else { return nil }
        return try? JSONDecoder().decode(ItemConfig.self, from: data)
    }

    func handleScheduledStart(activity: DeviceActivityName) {
        guard let config = retrieveConfig(for: activity) else { return }
        BlockController.shared.applyShield(for: config)
    }

    func handleScheduledEnd(activity: DeviceActivityName) {
        guard let config = retrieveConfig(for: activity) else { return }
        BlockController.shared.clearShield(for: config)

        if config.blockMode == .limit {
            BlockController.shared.createThreshold(
                for: config,
                threshold: config.limitConfig.freeTime
            )
        }
    }

    func handleLimitBlock(activity: DeviceActivityName, config: ItemConfig) {
        try? BlockController.shared.createScheduled(
            for: config,
            start: .now,
            end: .now.addingTimeInterval(config.limitConfig.breakTime)
        )
    }

    func handleOpensBlock(activity: DeviceActivityName, config: ItemConfig) {
        BlockController.shared.applyShield(for: config)
    }
}
