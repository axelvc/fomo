//
//  Item.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import Foundation
import ManagedSettings
import SwiftData

@Model
final class Item {
    @Attribute(.unique)
    var id: UUID
    
    var name: String

    var apps: Set<ApplicationToken>

    var _blockMode: BlockMode
    @Transient var blockMode: BlockMode {
        get { _blockMode }
        set {
            guard _blockMode != newValue else { return }
            _blockMode = newValue
            resetLimitMode()
        }
    }

    var timerDuration: Duration
    var scheduleWindow: ScheduleWindow
    var limitConfig: LimitConfig
    var opensConfig: OpensConfig

    var breakMode: BreakMode
    var repeatOn: Bool
    var notificationOn: Bool

    init() {
        self.id = UUID()
        self.name = ""
        self.apps = []
        self._blockMode = .timer
        self.breakMode = .relaxed
        self.repeatOn = false
        self.notificationOn = false
        self.timerDuration = .init()
        self.scheduleWindow = .init()
        self.limitConfig = .init()
        self.opensConfig = .init()
    }
    
    private func resetLimitMode() {
        switch blockMode {
        case .timer:
            timerDuration = .init()
        case .schedule:
            scheduleWindow = .init()
        case .limit:
            limitConfig = .init()
        case .opens:
            opensConfig = .init()
        }
    }
}

extension Item {
    var isValid: Bool {
        if name.isEmpty { return false }
        // if apps.isEmpty { return false }
        
        return switch blockMode {
        case .timer:
            timerDuration.totalSeconds > 0
        case .schedule:
            scheduleWindow.start < scheduleWindow.end
        case .limit:
            limitConfig.breakTime.totalSeconds > 0
            && limitConfig.freeTime.totalSeconds > 0
        case .opens:
            opensConfig.opens > 0
            && opensConfig.allowedPerOpen.totalSeconds > 0
        }
    }
}

extension Item {
    @MainActor func block() {
        switch blockMode {
        case .timer: blockTimer()
        case .schedule: blockSchedule()
        case .limit: blockLimit()
        case .opens: blockOpens()
        }
        
    }
    
    @MainActor private func blockTimer() {
        BlockController.shared.applyBlock(for: apps)
        
        Task {
            try? await Task.sleep(for: .seconds(timerDuration.totalSeconds))
            BlockController.shared.clearBlock()
        }
    }
    
    @MainActor private func blockSchedule() {
        try? BlockController.shared.startSchedule(for: self)
    }
    
    @MainActor private func blockLimit() {
        BlockController.shared.startLimit(for: self)
    }
    
    @MainActor private func blockOpens() {
        //
    }
}

enum BreakMode: String, Codable, CaseIterable, Identifiable {
    case relaxed, focused, strict

    var id: Self { self }
    var title: String { self.rawValue.capitalized }
}

enum BlockMode: String, Codable, CaseIterable, Identifiable {
    case timer, schedule, limit, opens

    var id: String { title }
    var title: String { self.rawValue.capitalized }
}

struct Duration: Codable {
    var hours: Int = 0
    var minutes: Int = 0
    
    var totalSeconds: Int { hours * 3600 + minutes * 60 }
}

struct ScheduleWindow: Codable {
    var start: Date = .distantPast
    var end: Date = .distantFuture
}

struct LimitConfig: Codable {
    var freeTime: Duration = .init()
    var breakTime: Duration = .init()
}

struct OpensConfig: Codable {
    var opens: Int = 0
    var allowedPerOpen: Duration = .init()
}
