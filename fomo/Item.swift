//
//  Item.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import Foundation
import ManagedSettings
import SwiftData
import FamilyControls

@Model
final class Item: ItemProtocol {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var activitySelection: FamilyActivitySelection
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
        self.activitySelection = .init()
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
            if activitySelection.applicationTokens.isEmpty { return false }
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
    var start: Date
    var end: Date

    init(start: Date = emptyDate, end: Date = emptyDate) {
        self.start = start
        self.end = end
    }

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
    var openLeft = 0
    var allowedPerOpen: Int = 0
}

struct ItemConfig: ItemProtocol, Codable {
    let id: UUID
    var blockMode: BlockMode
    var activitySelection: FamilyActivitySelection
    var timerDuration: Duration
    var scheduleWindow: ScheduleWindow
    var limitConfig: LimitConfig
    var opensConfig: OpensConfig

    init(from item: ItemProtocol) {
        self.id = item.id
        self.blockMode = item.blockMode
        self.activitySelection = item.activitySelection
        self.timerDuration = item.timerDuration
        self.scheduleWindow = item.scheduleWindow
        self.limitConfig = item.limitConfig
        self.opensConfig = item.opensConfig
    }
}

protocol ItemProtocol {
    var id: UUID { get }
    var blockMode: BlockMode { get }
    var activitySelection: FamilyActivitySelection { get }
    var timerDuration: Duration { get }
    var scheduleWindow: ScheduleWindow { get }
    var limitConfig: LimitConfig { get }
    var opensConfig: OpensConfig { get set }
}

enum SharedDefaults {
    static let suiteName = "group.axelvc.fomo"
    static var shared: UserDefaults { .init(suiteName: suiteName)! }
}
