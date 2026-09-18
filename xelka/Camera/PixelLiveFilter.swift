//
//  PixelLiveFilter.swift
//  xelka
//
//  GPU pixel-art for live video. Two Core Image stages:
//    1. CIPixellate — average the frame into square blocks (the chunkiness)
//    2. CIColorCube — a 3D LUT that snaps every color to the nearest palette
//       entry. The LUT is *built from the same `Palette.nearest` the still
//       engine uses*, so the live preview matches what capture will produce.
//
//  Fixed palettes (Game Boy, PICO-8) build their cube once and cache it.
//  The adaptive style (Modern Clean) rebuilds its cube every few frames from a
//  tiny render of the current frame, so it stays "colors from your photo" live.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

// Shared mutable state (adaptiveCube, isRebuilding) is guarded by `cubeLock`;
// everything else is either immutable or touched only on the capture queue.
//
// We cache LUT *data*, never CIFilter instances: a cached filter keeps its last
// `inputImage`, which retains the camera's CVPixelBuffer. One pinned buffer per
// visited palette drains AVCaptureVideoDataOutput's small pool after a few style
// switches, and the camera stops delivering frames (the preview freezes).
nonisolated final class PixelLiveFilter: @unchecked Sendable {
    private let context: CIContext
    private let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// One LUT per fixed palette, keyed by palette name (capture queue only).
    private var fixedCubes: [String: CubeLUT] = [:]
    private var adaptiveFrame = 0

    /// Current adaptive cube + rebuild state, shared with `rebuildQueue`.
    private let cubeLock = NSLock()
    private var adaptiveCube: CubeLUT?
    private var isRebuilding = false

    /// Adaptive palette refreshes run off the capture queue so frame delivery
    /// never stalls — that synchronous rebuild was the Modern Clean stutter.
    private let rebuildQueue = DispatchQueue(label: "com.jimmythegenius.xelka.adaptive", qos: .utility)

    /// Frames between adaptive-palette refreshes (~1.5/sec at 30fps).
    private let adaptiveRebuildEvery = 20
    private let cubeDimension = 48         // fixed palettes: built once, cached
    private let adaptiveCubeDimension = 32 // rebuilt live, so keep it cheaper

    /// A baked color cube: plain data, safe to cache and share across queues.
    private struct CubeLUT {
        let dimension: Int
        let data: Data
    }

    init(context: CIContext) {
        self.context = context
    }

    /// Pixelate + (optionally) dither + palette-map `input` for the given style.
    func apply(to input: CIImage, style: PixelArtStyle) -> CIImage {
        let ext = input.extent
        guard ext.width > 0, ext.height > 0, ext.width.isFinite else { return input }

        // 1. Chunk into blocks so the long edge holds ~style.resolution blocks.
        //    Center at origin so blocks align to the same grid the dither uses.
        let blockSize = max(1, Float(max(ext.width, ext.height)) / Float(style.effectiveResolution))
        let pix = CIFilter.pixellate()
        pix.inputImage = input
        pix.scale = blockSize
        pix.center = .zero
        var blocks = (pix.outputImage ?? input).cropped(to: ext)

        // 1b. Tone shaping (contrast/saturation/brightness) on the blocked image,
        //     matching the still engine's Preprocess order (after downsample,
        //     before dither) so the preview reflects the style's/preset's look.
        blocks = preprocessed(blocks, style.preprocess, extent: ext)

        // 2. Ordered dithering per art-block, before the palette snap — this is
        //    what makes the live feed match the dithered capture result.
        if style.dithering == .ordered {
            let spread = ditherSpread(for: style)
            if spread > 0, let kernel = Self.ditherKernel,
               let dithered = kernel.apply(extent: ext,
                                           roiCallback: { _, rect in rect },
                                           arguments: [blocks, blockSize, spread]) {
                blocks = dithered
            }
        }

        // 3. Snap colors to the palette via LUT. A fresh filter per frame is
        //    cheap and holds no reference to the frame once we return.
        guard let lut = cube(for: style, source: blocks) else { return blocks }
        let cube = CIFilter.colorCubeWithColorSpace()
        cube.cubeDimension = Float(lut.dimension)
        cube.cubeData = lut.data
        cube.colorSpace = workingSpace
        cube.inputImage = blocks
        return (cube.outputImage ?? blocks).cropped(to: ext)
    }

    /// Apply contrast/saturation/brightness via CIColorControls, whose formula
    /// (contrast around 0.5, additive brightness, saturation toward luma) mirrors
    /// the CPU engine's `applyPreprocess`. No-op at neutral so the common path
    /// stays cheap.
    private func preprocessed(_ image: CIImage, _ p: Preprocess, extent: CGRect) -> CIImage {
        guard p.contrast != 1 || p.saturation != 1 || p.brightness != 0 else { return image }
        let cc = CIFilter.colorControls()
        cc.inputImage = image
        cc.contrast = p.contrast
        cc.saturation = p.saturation
        cc.brightness = p.brightness
        return (cc.outputImage ?? image).cropped(to: extent)
    }

    /// Dither strength per palette — tonal ramps have wide gaps between few
    /// shades, so they need a larger nudge than full-color palettes. Matches the
    /// CPU engine's `orderedDither`.
    private func ditherSpread(for style: PixelArtStyle) -> Float {
        switch style.quantization {
        case .fixed(let p): return p.isTonal ? 0.20 : 0.11
        case .adaptive: return 0
        }
    }

    /// The Bayer dither kernel, loaded once from the app's default Metal library
    /// (compiled with `-fcikernel`). Nil if unavailable — dithering just no-ops.
    private static let ditherKernel: CIKernel? = {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib") else {
            ditherLoadDiagnostic = "metallib not found in \(Bundle.main.bundlePath)"
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            ditherLoadDiagnostic = "could not read \(url.lastPathComponent)"
            return nil
        }
        do {
            let kernel = try CIKernel(functionName: "orderedDither", fromMetalLibraryData: data)
            ditherLoadDiagnostic = "ok"
            return kernel
        } catch {
            ditherLoadDiagnostic = "init failed: \(error)"
            return nil
        }
    }()

    nonisolated(unsafe) static private(set) var ditherLoadDiagnostic = "not attempted"

    /// Test/diagnostic hook: did the dither kernel load from the metallib?
    static var isDitherKernelAvailable: Bool { ditherKernel != nil }

    // MARK: - Cube selection

    private func cube(for style: PixelArtStyle, source: CIImage) -> CubeLUT? {
        switch style.quantization {
        case .fixed(let palette):
            if let cached = fixedCubes[palette.name] { return cached }
            let built = buildCube(from: palette, dim: cubeDimension)
            fixedCubes[palette.name] = built
            return built

        case .adaptive(let maxColors):
            cubeLock.lock(); let current = adaptiveCube; cubeLock.unlock()

            if current == nil {
                // First frame of this style: build once synchronously so the
                // look is correct immediately (one small hitch on switch).
                guard let px = sampleFramePixels(from: source) else { return nil }
                let built = buildCube(from: AdaptivePalette.build(from: px, maxColors: maxColors),
                                      dim: adaptiveCubeDimension)
                cubeLock.lock(); adaptiveCube = built; cubeLock.unlock()
                return built
            }

            // Refresh off the capture queue, throttled — frames keep using the
            // current cube until the new one is swapped in.
            adaptiveFrame += 1
            if adaptiveFrame % adaptiveRebuildEvery == 0, let px = sampleFramePixels(from: source) {
                scheduleAdaptiveRebuild(pixels: px, maxColors: maxColors)
            }
            return current
        }
    }

    /// Median-cut + cube build on a background queue; swap in when ready.
    private func scheduleAdaptiveRebuild(pixels: [RGBColor], maxColors: Int) {
        cubeLock.lock()
        if isRebuilding { cubeLock.unlock(); return }
        isRebuilding = true
        cubeLock.unlock()

        rebuildQueue.async { [weak self] in
            guard let self else { return }
            let palette = AdaptivePalette.build(from: pixels, maxColors: maxColors)
            let built = self.buildCube(from: palette, dim: self.adaptiveCubeDimension)
            self.cubeLock.lock()
            self.adaptiveCube = built
            self.isRebuilding = false
            self.cubeLock.unlock()
        }
    }

    // MARK: - Cube construction

    /// Bake a dim³ RGBA LUT where every cell holds its nearest palette color.
    private func buildCube(from palette: Palette, dim: Int) -> CubeLUT {
        var data = [Float](repeating: 0, count: dim * dim * dim * 4)
        var o = 0
        // CIColorCube layout: R varies fastest, then G, then B.
        for bi in 0..<dim {
            let b = Float(bi) / Float(dim - 1)
            for gi in 0..<dim {
                let g = Float(gi) / Float(dim - 1)
                for ri in 0..<dim {
                    let r = Float(ri) / Float(dim - 1)
                    let n = palette.nearest(to: RGBColor(r: r, g: g, b: b))
                    data[o] = n.r; data[o + 1] = n.g; data[o + 2] = n.b; data[o + 3] = 1
                    o += 4
                }
            }
        }
        return CubeLUT(dimension: dim, data: data.withUnsafeBytes { Data($0) })
    }

    /// Render a tiny (~44px) version of the current frame and read its pixels.
    /// Runs on the capture queue (the frame buffer is only valid there); the
    /// heavier median-cut over these pixels happens on `rebuildQueue`.
    private func sampleFramePixels(from image: CIImage) -> [RGBColor]? {
        let target: CGFloat = 44
        let ext = image.extent
        guard ext.width.isFinite, ext.width > 0 else { return nil }

        let s = target / max(ext.width, ext.height)
        let scaled = image
            .transformed(by: CGAffineTransform(translationX: -ext.minX, y: -ext.minY))
            .transformed(by: CGAffineTransform(scaleX: s, y: s))
        let w = max(1, Int((ext.width * s).rounded()))
        let h = max(1, Int((ext.height * s).rounded()))

        var buf = [UInt8](repeating: 0, count: w * h * 4)
        context.render(scaled, toBitmap: &buf, rowBytes: w * 4,
                       bounds: CGRect(x: 0, y: 0, width: w, height: h),
                       format: .RGBA8, colorSpace: workingSpace)

        var px = [RGBColor](); px.reserveCapacity(w * h)
        for i in 0..<(w * h) {
            let p = i * 4
            px.append(RGBColor(buf[p], buf[p + 1], buf[p + 2]))
        }
        return px
    }
}
