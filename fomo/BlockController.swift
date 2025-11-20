//
//  BlockController.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import Foundation
import ManagedSettings
import DeviceActivity

enum SharedDefaults {
    static let suiteName = "group.axelvc.fomo"
    static var shared: UserDefaults { .init(suiteName: suiteName)! }
}

extension DeviceActivityName {
    init(for item: Item) {
        self.init("fomo.schedule.\(item.id.uuidString)")
    }
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
}

nonisolated class FomoActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        Task { @MainActor in
            let raw = activity.rawValue
            guard
                let data = SharedDefaults.shared.data(forKey: raw),
                let tokens = try? JSONDecoder().decode([ApplicationToken].self, from: data)
            else {
                return
            }
            
            BlockController.shared.applyBlock(for: Set(tokens))
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        Task { @MainActor in
            BlockController.shared.clearBlock()
            SharedDefaults.shared.removeObject(forKey: activity.rawValue)
        }
    }
}
