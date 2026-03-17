//
//  ImperiumApp.swift
//  Imperium
//
//  Created by Sanskaar Nair on 2026-03-16.
//

import SwiftUI
import SwiftData

@main
struct ImperiumApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LogEntry.self,
            Insight.self,
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
