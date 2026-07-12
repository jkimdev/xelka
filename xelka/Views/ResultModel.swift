//
//  ResultModel.swift
//  xelka
//
//  Holds the captured source image and re-runs the engine whenever the chosen
//  style or dithering changes. Heavy work happens off the main actor; the UI
//  just observes `output`. Because we keep the original source around, switching
//  styles is instant and lossless (never re-quantizing already-quantized art).
//

import SwiftUI

@MainActor
@Observable
final class ResultModel {
    let source: CGImage
    private(set) var style: PixelArtStyle
    private(set) var dithering: Dithering
    private(set) var resolution: Int
    private(set) var output: CGImage?
    private(set) var isProcessing = false

    private var job: Task<Void, Never>?

    init(source: CGImage, style: PixelArtStyle) {
        self.source = source
        self.style = style
        self.dithering = style.dithering
        self.resolution = style.resolution
        reprocess()
    }

    func select(_ newStyle: PixelArtStyle) {
        guard newStyle.id != style.id else { return }
        style = newStyle
        dithering = newStyle.dithering
        resolution = newStyle.resolution
        reprocess()
    }

    func setDithering(_ d: Dithering) {
        guard d != dithering else { return }
        dithering = d
        reprocess()
    }

    /// Pixel-size slider. Lower resolution = chunkier pixels.
    func setResolution(_ r: Int) {
        guard r != resolution else { return }
        resolution = r
        reprocess()
    }

    /// Current style with the live dithering + resolution overrides folded in.
    private var effectiveStyle: PixelArtStyle {
        var s = style
        s.dithering = dithering
        s.resolutionOverride = resolution
        return s
    }

    private func reprocess() {
        job?.cancel()
        isProcessing = true
        let src = source
        let s = effectiveStyle
        job = Task {
            let result = await Task.detached(priority: .userInitiated) {
                PixelArtEngine.process(src, style: s)
            }.value
            if Task.isCancelled { return }
            output = result
            isProcessing = false
        }
    }

    /// Bake a large, crisp version for saving/sharing (nil until first render).
    func bakedForExport(longEdge: Int = 1024) async -> CGImage? {
        let src = source
        let s = effectiveStyle
        return await Task.detached(priority: .userInitiated) {
            guard let small = PixelArtEngine.process(src, style: s) else { return nil }
            return PixelArtEngine.render(small, scaledTo: longEdge)
        }.value
    }
}
