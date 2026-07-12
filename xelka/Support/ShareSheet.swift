//
//  ShareSheet.swift
//  xelka
//
//  A thin SwiftUI wrapper over UIActivityViewController so finished pixel art can
//  be sent straight to Instagram / Messages / Save-to-Files from the result
//  screen. Presented via `.sheet(item:)` once the export image is baked.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
