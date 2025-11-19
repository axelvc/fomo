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
            timerDuration = Duration()
        case .schedule:
            scheduleWindow = ScheduleWindow()
        case .limit:
            limitConfig = LimitConfig()
        case .opens:
            opensConfig = OpensConfig()
        }
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
}

struct ScheduleWindow: Codable {
    var start: Date = .distantPast
    var end: Date = .distantFuture
}

struct LimitConfig: Codable {
    var focus: Duration = .init()
    var breakTime: Duration = .init()
}

struct OpensConfig: Codable {
    var opens: Int = 0
    var allowedPerOpen: Duration = .init()
}
