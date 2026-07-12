//
//  ContentView.swift
//  xelka
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CameraScreen()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PixelShot.self, inMemory: true)
}
