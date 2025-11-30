//
//  fomoApp.swift
//  fomo
//
//  Created by Axel on 17/11/25.
//

import FamilyControls
import SwiftData
import SwiftUI

@main
struct fomoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var auth = ScreenTimeAuthorization()

    var body: some Scene {
        WindowGroup {
            if auth.status == .approved {
                ContentView()
            } else {
                AuthorizationView(model: auth)
                    .onAppear {
                        auth.refresh()
                    }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: ScenePhase.active) { _, _ in
            auth.refresh()
        }
    }
}
