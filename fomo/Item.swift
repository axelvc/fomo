//
//  Item.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import Foundation
import SwiftData
import FamilyControls

@Model
final class Item {
    var name: String
    
    var apps: FamilyActivitySelection
    var blockMode: BlockMode
    var breakMode: BreakMode
    
    var repeatOn: Bool
    var notificationOn: Bool
    
    init(name: String) {
        self.name = name
        self.apps = .init()
        self.blockMode = .timer(.init(hours: 0, minutes: 0))
        self.breakMode = .relaxed
        self.repeatOn = false
        self.notificationOn = false
    }
}

enum BreakMode: String, Codable, CaseIterable, Identifiable {
    case relaxed, focused, strict
    
    var id: Self { self }
    var title: String { self.rawValue.capitalized }
}

enum BlockMode: Codable, CaseIterable, Identifiable, Hashable {
    case timer(Duration)
    case schedule(ScheduleWindow)
    case limit(LimitConfig)
    case opens(OpensConfig)
    
    static var allCases: [BlockMode] {
        [
            .timer(.init()),
            .schedule(.init()),
            .limit(.init()),
            .opens(.init())
        ]
    }
    
    var id: String { title }
    
    var title: String {
        return switch self {
        case .timer: "Timer"
        case .schedule: "Schedule"
        case .limit: "Limit"
        case .opens: "Opens"
        }
    }
}

struct Duration: Codable, Hashable {
    var hours: Int = 0
    var minutes: Int = 0
}

struct ScheduleWindow: Codable, Hashable {
    var start: Date = .distantPast
    var end: Date = .distantFuture
}

struct LimitConfig: Codable, Hashable {
    var focus: Duration = .init()
    var breakTime: Duration = .init()
}

struct OpensConfig: Codable, Hashable {
    var opens: Int = 0
    var allowedPerOpen: Duration = .init()
}
