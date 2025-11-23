//
//  ScreenTimeAuth.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import Foundation
import FamilyControls

@MainActor
@Observable
final class ScreenTimeAuthorization {
    var status: AuthorizationStatus = .notDetermined
    private let center = AuthorizationCenter.shared

    func request() {
        Task {
            do {
                try await center.requestAuthorization(for: .individual)
                status = center.authorizationStatus
            } catch {
                print("Authorization failed: \(error)")
                status = center.authorizationStatus
            }
        }
    }

    func refresh() {
        status = center.authorizationStatus
    }
}
