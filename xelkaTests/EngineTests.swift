//
//  EngineTests.swift
//  xelkaTests
//
//  Pure-logic tests for the pixel-art engine — no camera or UI involved.
//

import Testing
import CoreGraphics
@testable import xelka

struct EngineTests {

    /// A solid-color w×h sRGB image to feed the pipeline.
    static func solid(_ c: (UInt8, UInt8, UInt8), w: Int, h: Int) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255,
                         blue: CGFloat(c.2) / 255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    @Test func tonalGameBoyMapsExtremesToRampEnds() {
        let gb = Palette.gameBoy
        #expect(gb.nearest(to: RGBColor(0, 0, 0)) == gb.sortedByLuma.first!)
        #expect(gb.nearest(to: RGBColor(255, 255, 255)) == gb.sortedByLuma.last!)
    }

    @Test func fixedPaletteColorsMatchThemselves() {
        let p = Palette.pico8
        for c in p.colors {
            #expect(p.nearest(to: c) == c)
        }
    }

    @Test func adaptivePaletteRespectsMaxColors() {
        var px: [RGBColor] = []
        for i in 0..<512 {
            px.append(RGBColor(UInt8(i % 256), UInt8((i * 2) % 256), UInt8((i * 5) % 256)))
        }
        let pal = AdaptivePalette.build(from: px, maxColors: 16)
        #expect(pal.count <= 16)
        #expect(pal.count >= 1)
    }

    @Test func adaptivePaletteOfSolidImageIsOneColor() {
        let px = [RGBColor](repeating: RGBColor(120, 30, 200), count: 100)
        let pal = AdaptivePalette.build(from: px, maxColors: 16)
        #expect(pal.count == 1)
    }

    @Test func downsampleKeepsAspectRatio() {
        let img = Self.solid((10, 20, 30), w: 100, h: 50)
        let grid = PixelArtEngine.downsample(img, longEdge: 20)
        #expect(grid.width == 20)
        #expect(grid.height == 10)
    }

    @Test(arguments: PixelArtStyle.presets.map { $0.id })
    func processProducesArtAtOrBelowStyleResolution(styleID: String) {
        let style = PixelArtStyle.presets.first { $0.id == styleID }!
        let img = Self.solid((200, 50, 50), w: 256, h: 128)
        let out = PixelArtEngine.process(img, style: style)
        #expect(out != nil)
        if let out {
            #expect(max(out.width, out.height) <= style.resolution)
        }
    }

    @Test func exportUpscalesCrisplyByInteger() {
        let img = Self.solid((0, 0, 0), w: 128, h: 128)
        let small = PixelArtEngine.process(img, style: .gameBoy)!
        let big = PixelArtEngine.render(small, scaledTo: 1024)!
        // Upscale factor is an integer multiple, so pixels stay square.
        #expect(big.width % small.width == 0)
        #expect(big.width >= small.width)
    }
}
