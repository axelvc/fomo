//
//  AuthorizationView.swift
//  fomo
//
//  Created by Axel on 30/11/25.
//

import FamilyControls
import SwiftUI

struct AuthorizationView: View {
  @Bindable var model: ScreenTimeAuthorization

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "hourglass")
        .font(.system(size: 80))
        .foregroundStyle(.blue)
        .padding(.bottom, 20)

      Text("Screen Time Access Required")
        .font(.title2)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)

      Text("To help you stay focused, Fomo needs permission to access Screen Time settings.")
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal)

      if model.status == .denied {
        VStack(spacing: 12) {
          Text("Permission Denied")
            .font(.headline)
            .foregroundStyle(.red)

          Text("Please enable Screen Time access in Settings to use this app.")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

          Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(.top, 20)
      } else {
        Button("Authorize") {
          model.request()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.top, 20)
      }
    }
    .padding()
  }
}

#Preview {
  AuthorizationView(model: ScreenTimeAuthorization())
}
