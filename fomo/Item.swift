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
    var breakMode: BreakMode

    var timerDuration: Duration
    var scheduleWindow: ScheduleWindow
    var limitConfig: LimitConfig
    var opensConfig: OpensConfig

    var _blockMode: BlockMode
    @Transient var blockMode: BlockMode {
        get { _blockMode }
        set {
            guard _blockMode != newValue else { return }
            _blockMode = newValue
            resetLimitMode()
        }
    }

    init() {
        self.id = UUID()
        self.name = ""
        self.apps = []
        self._blockMode = .timer
        self.breakMode = .relaxed
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

    var isValid: Bool {
        if name.isEmpty { return false }

        #if !targetEnvironment(simulator)
            if apps.isEmpty { return false }
        #endif

        return switch blockMode {
        case .timer:
            timerDuration.totalSeconds > 0
        case .schedule:
            scheduleWindow.start != scheduleWindow.end
        case .limit:
            limitConfig.freeTime.totalSeconds > 0
                && limitConfig.breakTime.totalSeconds > 0
        case .opens:
            opensConfig.opens > 0
                && opensConfig.allowedPerOpen > 0
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

    var totalSeconds: Int { hours * 3600 + minutes * 60 }
}

struct ScheduleWindow: Codable {
    var start: Date = emptyDate
    var end: Date = emptyDate

    init() {}

    init(of duration: Duration) {
        start = .now
        end = start.addingTimeInterval(TimeInterval(duration.totalSeconds))
    }

    private static var emptyDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

struct LimitConfig: Codable {
    var freeTime: Duration = .init()
    var breakTime: Duration = .init()
}

struct OpensConfig: Codable {
    var opens: Int = 0
    var allowedPerOpen: Int = 0
}
