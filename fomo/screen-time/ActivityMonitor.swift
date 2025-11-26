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
                let data = SharedDefaults.shared.data(forKey: rawKey)
            else { return }

            if let limitStorage = try? JSONDecoder().decode(
                LimitStorage.self,
                from: data
            ) {
                await handleLimitStorage(
                    storage: limitStorage,
                    activity: activity
                )
                return
            }

            if let opensStorage = try? JSONDecoder().decode(
                OpensStorage.self,
                from: data
            ) {
                handleOpensStorage(
                    storage: opensStorage,
                    activity: activity
                )
            }
        }
    }
}

private extension ActivityMonitor {
    @MainActor
    func handleLimitStorage(
        storage: LimitStorage,
        activity: DeviceActivityName
    ) async {
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

    @MainActor
    func handleOpensStorage(
        storage: OpensStorage,
        activity: DeviceActivityName
    ) {
        let remainingOpens = max(storage.openLeft - 1, 0)

        let updatedStorage = OpensStorage(
            tokens: storage.tokens,
            allowedPerOpen: storage.allowedPerOpen,
            opensLimit: storage.opensLimit,
            openLeft: remainingOpens
        )

        if let encoded = try? JSONEncoder().encode(updatedStorage) {
            SharedDefaults.shared.set(
                encoded,
                forKey: activity.rawValue
            )
        }

        guard remainingOpens == 0 else { return }

        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])

        let tokens = Set(storage.tokens)
        BlockController.shared.applyBlock(for: tokens)
        SharedDefaults.shared.removeObject(forKey: activity.rawValue)
    }
}
