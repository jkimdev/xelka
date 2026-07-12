//
//  PixelArtEngine.swift
//  xelka
//
//  The whole pixel-art pipeline, as pure CoreGraphics + math so it runs on any
//  background thread and is trivially unit-testable:
//
//      CGImage → downsample → preprocess → quantize(+dither) → small CGImage
//
//  The output is a *small* CGImage (one pixel per art pixel). The UI renders it
//  with nearest-neighbor scaling so it stays crisp; `render(_:scaledTo:)` bakes
//  that same crisp upscale for export/saving.
//

import CoreGraphics
import Foundation

/// A grid of colors — the intermediate the pipeline passes around.
struct PixelGrid: Sendable {
    var width: Int
    var height: Int
    var pixels: [RGBColor] // row-major, width*height
}

enum PixelArtEngine {

    /// Run a full style over a source image. Returns a small (art-resolution)
    /// CGImage, or nil if the source can't be read.
    nonisolated static func process(_ source: CGImage, style: PixelArtStyle) -> CGImage? {
        let grid = downsample(source, longEdge: style.effectiveResolution)
        guard grid.width > 0, grid.height > 0 else { return nil }

        var work = grid
        applyPreprocess(&work, style.preprocess)

        let palette: Palette
        switch style.quantization {
        case .fixed(let p): palette = p
        case .adaptive(let maxColors):
            palette = AdaptivePalette.build(from: work.pixels, maxColors: maxColors)
        }

        quantize(&work, palette: palette, dithering: style.dithering)
        return makeCGImage(from: work)
    }

    // MARK: - Downsample

    /// Shrink so the long edge is `longEdge` pixels, averaging source detail
    /// (medium interpolation ≈ box filter). This is where a photo becomes chunky.
    nonisolated static func downsample(_ image: CGImage, longEdge: Int) -> PixelGrid {
        let srcW = image.width, srcH = image.height
        guard srcW > 0, srcH > 0 else { return PixelGrid(width: 0, height: 0, pixels: []) }

        let scale = Float(longEdge) / Float(max(srcW, srcH))
        let w = max(1, Int((Float(srcW) * scale).rounded()))
        let h = max(1, Int((Float(srcH) * scale).rounded()))

        return PixelGrid(width: w, height: h, pixels: readPixels(image, width: w, height: h))
    }

    /// Draw `image` into a w×h sRGB RGBA8 context and read it back as RGBColor.
    private nonisolated static func readPixels(_ image: CGImage, width w: Int, height h: Int) -> [RGBColor] {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * h)

        let ok: Bool = data.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: w, height: h,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return [] }

        var pixels = [RGBColor](repeating: RGBColor(0, 0, 0), count: w * h)
        for i in 0..<(w * h) {
            let o = i * 4
            pixels[i] = RGBColor(data[o], data[o + 1], data[o + 2])
        }
        return pixels
    }

    // MARK: - Preprocess

    nonisolated static func applyPreprocess(_ grid: inout PixelGrid, _ p: Preprocess) {
        if p.contrast == 1 && p.saturation == 1 && p.brightness == 0 { return }
        for i in grid.pixels.indices {
            var c = grid.pixels[i]
            // brightness
            c.r += p.brightness; c.g += p.brightness; c.b += p.brightness
            // contrast around mid-grey
            c.r = (c.r - 0.5) * p.contrast + 0.5
            c.g = (c.g - 0.5) * p.contrast + 0.5
            c.b = (c.b - 0.5) * p.contrast + 0.5
            // saturation toward luminance
            if p.saturation != 1 {
                let l = c.luminance
                c.r = l + (c.r - l) * p.saturation
                c.g = l + (c.g - l) * p.saturation
                c.b = l + (c.b - l) * p.saturation
            }
            grid.pixels[i] = RGBColor(r: c.r.clamped01, g: c.g.clamped01, b: c.b.clamped01)
        }
    }

    // MARK: - Quantize + dither

    /// Normalized 4×4 Bayer matrix, values in 0...1 (centered offsets computed
    /// per-use). Classic ordered-dither threshold map.
    private static let bayer4: [Float] = [
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5,
    ].map { $0 / 16 }

    nonisolated static func quantize(_ grid: inout PixelGrid, palette: Palette, dithering: Dithering) {
        switch dithering {
        case .none:
            for i in grid.pixels.indices {
                grid.pixels[i] = palette.nearest(to: grid.pixels[i])
            }
        case .ordered:
            orderedDither(&grid, palette: palette)
        case .floydSteinberg:
            floydSteinberg(&grid, palette: palette)
        }
    }

    private nonisolated static func orderedDither(_ grid: inout PixelGrid, palette: Palette) {
        // Spread ≈ how far a pixel can be nudged toward a neighbouring level.
        // Tonal ramps have big gaps between few shades, so they need more.
        let spread: Float = palette.isTonal ? 0.20 : 0.11
        let w = grid.width
        for y in 0..<grid.height {
            for x in 0..<w {
                let t = (bayer4[(y & 3) * 4 + (x & 3)] - 0.5) * spread
                let i = y * w + x
                let c = grid.pixels[i]
                let nudged = RGBColor(r: (c.r + t).clamped01,
                                      g: (c.g + t).clamped01,
                                      b: (c.b + t).clamped01)
                grid.pixels[i] = palette.nearest(to: nudged)
            }
        }
    }

    private nonisolated static func floydSteinberg(_ grid: inout PixelGrid, palette: Palette) {
        let w = grid.width, h = grid.height
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let old = grid.pixels[i]
                let new = palette.nearest(to: old)
                grid.pixels[i] = new
                let er = old.r - new.r, eg = old.g - new.g, eb = old.b - new.b

                @inline(__always) func diffuse(_ dx: Int, _ dy: Int, _ f: Float) {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { return }
                    let j = ny * w + nx
                    var c = grid.pixels[j]
                    c.r = (c.r + er * f).clamped01
                    c.g = (c.g + eg * f).clamped01
                    c.b = (c.b + eb * f).clamped01
                    grid.pixels[j] = c
                }
                diffuse( 1, 0, 7.0 / 16)
                diffuse(-1, 1, 3.0 / 16)
                diffuse( 0, 1, 5.0 / 16)
                diffuse( 1, 1, 1.0 / 16)
            }
        }
    }

    // MARK: - Output

    /// Pack a grid back into a small opaque CGImage (one pixel per art pixel).
    nonisolated static func makeCGImage(from grid: PixelGrid) -> CGImage? {
        let w = grid.width, h = grid.height
        guard w > 0, h > 0 else { return nil }
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 255, count: bytesPerRow * h)
        for i in 0..<(w * h) {
            let o = i * 4
            let c = grid.pixels[i]
            data[o] = c.r8; data[o + 1] = c.g8; data[o + 2] = c.b8; data[o + 3] = 255
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Bake a crisp nearest-neighbor upscale of a small art image to `target`
    /// pixels on the long edge — for saving/sharing at a usable size.
    nonisolated static func render(_ small: CGImage, scaledTo target: Int) -> CGImage? {
        let w = small.width, h = small.height
        guard w > 0, h > 0 else { return nil }
        let scale = max(1, target / max(w, h))
        let outW = w * scale, outH = h * scale
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(small, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        return ctx.makeImage()
    }
}
