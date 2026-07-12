//
//  MetalCameraView.swift
//  xelka
//
//  SwiftUI host for the MTKView that the LivePreviewRenderer draws into.
//  Replaces the plain AVCaptureVideoPreviewLayer so the feed can be pixelated.
//

#if os(iOS)
import SwiftUI
import MetalKit

struct MetalCameraView: UIViewRepresentable {
    let renderer: LivePreviewRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        renderer.attach(view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
#endif
