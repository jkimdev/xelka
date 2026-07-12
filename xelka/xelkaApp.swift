//
//  xelkaApp.swift
//  xelka
//
//  Created by jimmy on 7/11/26.
//

import SwiftUI
import SwiftData

@main
struct xelkaApp: App {
    @State private var proStore = ProStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PixelShot.self,
            CustomPreset.self,
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
                .environment(proStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
