//
//  Item.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import FamilyControls
import Foundation
import SwiftData

@Model
final class Item: ItemProtocol {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var activitySelection: FamilyActivitySelection
    var breakMode: BreakMode

    var timerDuration: TimeInterval
    var scheduleWindow: DateInterval
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
        self.timerDuration = 0
        self.scheduleWindow = .zero
        self.limitConfig = .init()
        self.opensConfig = .init()
    }

    private func resetLimitMode() {
        switch blockMode {
        case .timer:
            timerDuration = 0
        case .schedule:
            scheduleWindow = .zero
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
            timerDuration > 0
        case .schedule:
            scheduleWindow.duration > 0
        case .limit:
            limitConfig.freeTime > 0
                && limitConfig.breakTime > 0
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

struct LimitConfig: Codable {
    var freeTime: TimeInterval = 0
    var breakTime: TimeInterval = 0
}

struct OpensConfig: Codable {
    var opens: Int = 0
    var opensLeft: Int = 0
    var allowedPerOpen: Int = 0
}

struct ItemConfig: ItemProtocol, Codable {
    let id: UUID
    var blockMode: BlockMode
    var activitySelection: FamilyActivitySelection
    var timerDuration: TimeInterval
    var scheduleWindow: DateInterval
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
    var timerDuration: TimeInterval { get }
    var scheduleWindow: DateInterval { get }
    var limitConfig: LimitConfig { get }
    var opensConfig: OpensConfig { get set }
}

enum SharedDefaults {
    static let suiteName = "group.axelvc.fomo"
    static var shared: UserDefaults { .init(suiteName: suiteName)! }
}
