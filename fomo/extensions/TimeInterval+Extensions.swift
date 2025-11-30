//
//  TimeInterval+Extensions.swift
//  fomo
//
//  Created by Axel on 22/11/25.
//

import Foundation

extension TimeInterval {
    var hours: Int {
        Int(self / 3600)
    }

    var minutes: Int {
        Int((truncatingRemainder(dividingBy: 3600)) / 60)
    }

    init(hours: Int = 0, minutes: Int = 0) {
        self = TimeInterval(hours * 3600 + minutes * 60)
    }
}
