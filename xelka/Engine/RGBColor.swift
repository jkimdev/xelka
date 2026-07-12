//
//  RGBColor.swift
//  xelka
//
//  A tiny, allocation-free color value used throughout the pixel-art engine.
//  Channels are stored as Float in 0...1 for math; conversions to/from the
//  8-bit RGBA buffers that CoreGraphics hands us live here too.
//

import CoreGraphics

/// A linear-ish sRGB color. We do the whole pipeline in gamma sRGB space on
/// purpose — pixel art palettes were authored in sRGB and matching there gives
/// the look people expect.
struct RGBColor: Sendable, Equatable {
    var r: Float
    var g: Float
    var b: Float

    init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Build from 8-bit channels (0...255), e.g. a hex swatch in a palette.
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = Float(r) / 255
        self.g = Float(g) / 255
        self.b = Float(b) / 255
    }

    /// Build from a packed 0xRRGGBB literal — the convenient way to type palettes.
    init(hex: UInt32) {
        self.init(UInt8((hex >> 16) & 0xFF),
                  UInt8((hex >> 8) & 0xFF),
                  UInt8(hex & 0xFF))
    }

    /// Perceptual luminance (Rec. 601 weights). Drives tonal palette matching.
    var luminance: Float {
        0.299 * r + 0.587 * g + 0.114 * b
    }

    var r8: UInt8 { UInt8((r.clamped01 * 255).rounded()) }
    var g8: UInt8 { UInt8((g.clamped01 * 255).rounded()) }
    var b8: UInt8 { UInt8((b.clamped01 * 255).rounded()) }

    /// "Redmean" weighted distance — a cheap approximation of perceptual color
    /// difference that beats plain Euclidean RGB, especially for skin tones.
    /// Returns a squared magnitude (fine for nearest-neighbor comparisons).
    func distanceSquared(to o: RGBColor) -> Float {
        let rmean = (r + o.r) * 0.5
        let dr = r - o.r
        let dg = g - o.g
        let db = b - o.b
        return (2 + rmean) * dr * dr
             + 4 * dg * dg
             + (2 + (1 - rmean)) * db * db
    }
}

extension Float {
    var clamped01: Float { self < 0 ? 0 : (self > 1 ? 1 : self) }
}
