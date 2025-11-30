//
//  ScreenTimeAuth.swift
//  fomo
//
//  Created by Axel on 19/11/25.
//

import FamilyControls
import Foundation

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

    func checkAuthorization() async {
        status = center.authorizationStatus
        if status == .notDetermined {
            // Optionally request automatically, or wait for user action
            // For now, we rely on user action in the view
        }
    }
}
