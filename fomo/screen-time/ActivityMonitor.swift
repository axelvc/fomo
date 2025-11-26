//
//  ActivityMonitor.swift
//  fomo
//
//  Created by Axel on 22/11/25.
//


import Foundation
import DeviceActivity
import ManagedSettings

nonisolated class ActivityMonitor: DeviceActivityMonitor {
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

        guard event == limitReachedEvent else { return }

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
            BlockController.shared.repeatLimit(
                activity: activity,
                storage: storage,
                center: center
            )
        }
    }
}
