//
//  MonetizationTests.swift
//  xelkaTests
//
//  Covers the free/Pro split (which styles are gated) and the watermark
//  compositing. StoreKit purchase flow itself is exercised manually in the
//  simulator with the local .storekit config; here we test the pure logic.
//

import Testing
import CoreGraphics
@testable import xelka

struct MonetizationTests {

    @Test func originalThreeStylesAreFree() {
        for id in ["gameboy", "pico8", "modern"] {
            let style = PixelArtStyle.presets.first { $0.id == id }!
            #expect(style.isPremium == false)
        }
    }

    @Test func addedStylesArePremium() {
        let free: Set<String> = ["gameboy", "pico8", "modern"]
        let premium = PixelArtStyle.presets.filter { !free.contains($0.id) }
        #expect(premium.isEmpty == false)
        for style in premium {
            #expect(style.isPremium == true)
        }
    }

    @Test func proProductIDMatchesConfig() {
        // Must line up with xelka.storekit and App Store Connect.
        #expect(ProStore.productID == "com.jimmythegenius.xelka.pro")
    }

    #if canImport(UIKit)
    @Test func watermarkPreservesDimensions() {
        let src = EngineTests.solid((30, 120, 200), w: 512, h: 384)
        let stamped = Watermark.stamp(src)
        #expect(stamped.width == src.width)
        #expect(stamped.height == src.height)
    }

    @Test func watermarkChangesPixels() {
        // Stamping a flat image must alter some pixels (the wordmark region).
        let src = EngineTests.solid((0, 0, 0), w: 256, h: 256)
        let stamped = Watermark.stamp(src)
        #expect(pixelData(stamped) != pixelData(src))
    }

    /// Raw RGBA bytes of a CGImage, for equality comparison.
    private func pixelData(_ image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h,
                                bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return bytes
    }
    #endif
}
