//
//  DateInterval+Extensions.swift
//  fomo
//
//  Created by Axel on 29/11/25.
//

import Foundation

extension DateInterval {
    static var zero: Self {
        .init(
            start: Calendar.current.startOfDay(for: Date()),
            end: Calendar.current.startOfDay(for: Date())
        )
    }
}
