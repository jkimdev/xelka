//
//  PixelArtStyle.swift
//  xelka
//
//  A style is the full recipe the engine follows: how small to shrink the
//  image, how to nudge tones before quantizing, which palette strategy to use,
//  and how to dither. Adding a new look = adding one value here. Nothing in the
//  engine or UI hard-codes a specific style.
//

import Foundation

/// How pixels get mapped to a limited set of colors.
enum Quantization: Sendable {
    /// Snap to a fixed, hand-authored palette (Game Boy, PICO-8, …).
    case fixed(Palette)
    /// Derive an N-color palette from the photo itself (Modern Clean).
    case adaptive(maxColors: Int)
}

/// How we break up flat bands of color to fake extra shades.
enum Dithering: String, Sendable, CaseIterable, Identifiable {
    case none
    case ordered        // 4×4 Bayer — regular, "retro screen" texture
    case floydSteinberg // error diffusion — smoother, more organic

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "None"
        case .ordered: "Ordered"
        case .floydSteinberg: "Diffuse"
        }
    }
}

/// Light tone shaping applied before quantization. Multipliers around 1.0.
struct Preprocess: Sendable {
    var contrast: Float = 1.0   // >1 pushes darks down / lights up around mid-grey
    var saturation: Float = 1.0 // >1 makes colors pop; 0 = greyscale
    var brightness: Float = 0.0 // additive, in -1...1

    static let neutral = Preprocess()
}

struct PixelArtStyle: Identifiable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    /// Number of pixels on the image's long edge — the "chunkiness" dial.
    let resolution: Int
    let quantization: Quantization
    var dithering: Dithering
    var preprocess: Preprocess

    /// The three original styles are free; everything added later is part of the
    /// paid Pro unlock. The engine ignores this — it only gates the picker UI.
    static let freeStyleIDs: Set<String> = ["gameboy", "pico8", "modern"]
    var isPremium: Bool { !PixelArtStyle.freeStyleIDs.contains(id) }

    /// User override for `resolution`, set by the pixel-size slider. When nil the
    /// style's authored `resolution` is used.
    var resolutionOverride: Int? = nil

    /// The long-edge pixel count the engine and live filter actually run at.
    var effectiveResolution: Int { resolutionOverride ?? resolution }

    /// A representative swatch strip for UI chips. Adaptive styles have no fixed
    /// colors, so we show a neutral ramp as a stand-in.
    var previewColors: [RGBColor] {
        switch quantization {
        case .fixed(let p): return p.colors
        case .adaptive:
            return (0..<6).map { i in
                let v = Float(i) / 5
                return RGBColor(r: v, g: v, b: v)
            }
        }
    }
}

// MARK: - The three shipping styles

extension PixelArtStyle {
    /// 2-bit olive duotone at Game Boy screen scale, contrast pushed and ordered
    /// dither on — the authentic DMG handheld look.
    static let gameBoy = PixelArtStyle(
        id: "gameboy",
        name: "Game Boy",
        subtitle: "4-color olive duotone",
        resolution: 128,
        quantization: .fixed(.gameBoy),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.15, saturation: 0, brightness: 0.02)
    )

    /// Vibrant 16-color fantasy-console look. Saturation nudged up so colors
    /// snap cleanly onto PICO-8's punchy swatches; ordered dither for game feel.
    static let pico8 = PixelArtStyle(
        id: "pico8",
        name: "PICO-8",
        subtitle: "16-color fantasy console",
        resolution: 128,
        quantization: .fixed(.pico8),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.08, saturation: 1.2, brightness: 0)
    )

    /// Clean, modern pixel art: a palette pulled from the photo, no dithering,
    /// slightly higher resolution for crisp flat blocks that keep the mood.
    static let modernClean = PixelArtStyle(
        id: "modern",
        name: "Modern Clean",
        subtitle: "24 colors, from your photo",
        resolution: 160,
        quantization: .adaptive(maxColors: 24),
        dithering: .none,
        preprocess: Preprocess(contrast: 1.05, saturation: 1.05, brightness: 0)
    )

    /// Neutral grayscale at handheld scale — the Game Boy Pocket look.
    static let gameBoyPocket = PixelArtStyle(
        id: "gbpocket",
        name: "Game Boy Pocket",
        subtitle: "4-shade grayscale",
        resolution: 128,
        quantization: .fixed(.grayscale),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.12, saturation: 0, brightness: 0.02)
    )

    /// Stark 1-bit black & white with error-diffusion — an inky, comic stipple.
    static let oneBit = PixelArtStyle(
        id: "onebit",
        name: "1-Bit Ink",
        subtitle: "black & white, dithered",
        resolution: 160,
        quantization: .fixed(.oneBit),
        dithering: .floydSteinberg,
        preprocess: Preprocess(contrast: 1.2, saturation: 0, brightness: 0)
    )

    /// Green phosphor CRT terminal glow.
    static let greenCRT = PixelArtStyle(
        id: "greencrt",
        name: "Green CRT",
        subtitle: "phosphor terminal",
        resolution: 128,
        quantization: .fixed(.greenCRT),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.15, saturation: 0, brightness: 0.02)
    )

    /// Amber phosphor CRT terminal glow.
    static let amberCRT = PixelArtStyle(
        id: "ambercrt",
        name: "Amber CRT",
        subtitle: "phosphor terminal",
        resolution: 128,
        quantization: .fixed(.amberCRT),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.15, saturation: 0, brightness: 0.02)
    )

    /// Warm sepia duotone — an old-photograph mood.
    static let sepia = PixelArtStyle(
        id: "sepia",
        name: "Sepia",
        subtitle: "old photograph",
        resolution: 160,
        quantization: .fixed(.sepia),
        dithering: .floydSteinberg,
        preprocess: Preprocess(contrast: 1.06, saturation: 0, brightness: 0.02)
    )

    /// Iconic 4-color CGA cyan/magenta DOS look.
    static let cga = PixelArtStyle(
        id: "cga",
        name: "CGA",
        subtitle: "4-color DOS",
        resolution: 128,
        quantization: .fixed(.cga),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.10, saturation: 1.25, brightness: 0)
    )

    /// Commodore 64 16-color home-computer palette.
    static let commodore64 = PixelArtStyle(
        id: "c64",
        name: "Commodore 64",
        subtitle: "16-color home computer",
        resolution: 128,
        quantization: .fixed(.commodore64),
        dithering: .ordered,
        preprocess: Preprocess(contrast: 1.08, saturation: 1.15, brightness: 0)
    )

    /// Punchy modern 16-color pixel art, no dither for crisp flat blocks.
    static let sweetie16 = PixelArtStyle(
        id: "sweetie16",
        name: "Sweetie 16",
        subtitle: "modern 16-color",
        resolution: 144,
        quantization: .fixed(.sweetie16),
        dithering: .none,
        preprocess: Preprocess(contrast: 1.05, saturation: 1.15, brightness: 0)
    )

    /// The full preset lineup, in picker order (crowd-pleasers first).
    static let presets: [PixelArtStyle] = [
        .gameBoy, .gameBoyPocket, .pico8, .sweetie16, .modernClean,
        .oneBit, .commodore64, .cga, .greenCRT, .amberCRT, .sepia,
    ]
}
