//
//  Palette.swift
//  xelka
//
//  A palette is just an ordered set of colors plus a matching strategy.
//  Two strategies exist:
//    - chroma: nearest color by redmean distance (full-color palettes like PICO-8)
//    - tonal:  match by luminance against a ramp (monochrome-tinted palettes
//              like the Game Boy, where all swatches share one hue)
//

import Foundation

struct Palette: Sendable {
    let name: String
    let colors: [RGBColor]

    /// When true, a pixel is matched to the swatch whose luminance is closest,
    /// preserving the classic 1-/2-bit "shades of one color" look regardless of
    /// the source hue. When false we match by perceptual color distance.
    let isTonal: Bool

    /// Luminance of each swatch, cached for tonal matching. Sorted ascending
    /// alongside `sortedByLuma` so ordered dithering can nudge between levels.
    let sortedByLuma: [RGBColor]

    init(name: String, colors: [RGBColor], isTonal: Bool) {
        self.name = name
        self.colors = colors
        self.isTonal = isTonal
        self.sortedByLuma = colors.sorted { $0.luminance < $1.luminance }
    }

    var count: Int { colors.count }

    /// Nearest palette color to `c`. For tonal palettes this is luminance-based;
    /// otherwise redmean color distance.
    func nearest(to c: RGBColor) -> RGBColor {
        if isTonal {
            return nearestTonal(luma: c.luminance)
        }
        var best = colors[0]
        var bestDist = Float.greatestFiniteMagnitude
        for p in colors {
            let d = c.distanceSquared(to: p)
            if d < bestDist {
                bestDist = d
                best = p
            }
        }
        return best
    }

    /// Map luminance to an *even* N-level ramp by rank, not by nearest absolute
    /// luminance. This is how classic Game Boy converters posterize: the tinted
    /// swatches act as ordered steps, so all four shades get used evenly even
    /// when two of them share nearly the same brightness (as the DMG greens do).
    private func nearestTonal(luma: Float) -> RGBColor {
        let levels = sortedByLuma.count
        let idx = Int((luma.clamped01 * Float(levels - 1)).rounded())
        return sortedByLuma[min(max(idx, 0), levels - 1)]
    }
}

// MARK: - Preset palettes

extension Palette {
    /// Original Game Boy DMG-01 screen: four shades of that unmistakable
    /// olive-green. Tonal, so any photo becomes a 2-bit green duotone by brightness.
    static let gameBoy = Palette(
        name: "Game Boy",
        colors: [
            RGBColor(hex: 0x0F380F), // darkest
            RGBColor(hex: 0x306230),
            RGBColor(hex: 0x8BAC0F),
            RGBColor(hex: 0x9BBC0F), // lightest
        ],
        isTonal: true
    )

    /// PICO-8 fantasy-console 16-color palette. Full-color, matched by chroma.
    static let pico8 = Palette(
        name: "PICO-8",
        colors: [
            RGBColor(hex: 0x000000), // black
            RGBColor(hex: 0x1D2B53), // dark blue
            RGBColor(hex: 0x7E2553), // dark purple
            RGBColor(hex: 0x008751), // dark green
            RGBColor(hex: 0xAB5236), // brown
            RGBColor(hex: 0x5F574F), // dark grey
            RGBColor(hex: 0xC2C3C7), // light grey
            RGBColor(hex: 0xFFF1E8), // white
            RGBColor(hex: 0xFF004D), // red
            RGBColor(hex: 0xFFA300), // orange
            RGBColor(hex: 0xFFEC27), // yellow
            RGBColor(hex: 0x00E436), // green
            RGBColor(hex: 0x29ADFF), // blue
            RGBColor(hex: 0x83769C), // lavender
            RGBColor(hex: 0xFF77A8), // pink
            RGBColor(hex: 0xFFCCAA), // peach
        ],
        isTonal: false
    )

    // MARK: Monochrome / single-hue ramps (tonal — matched by brightness)

    /// Neutral 4-shade grayscale — the Game Boy Pocket "no tint" look.
    static let grayscale = Palette(
        name: "Grayscale",
        colors: [
            RGBColor(hex: 0x0B0B0B),
            RGBColor(hex: 0x555555),
            RGBColor(hex: 0xA8A8A8),
            RGBColor(hex: 0xEDEDED),
        ],
        isTonal: true
    )

    /// Pure 1-bit black & white — pairs with error-diffusion for an inky stipple.
    static let oneBit = Palette(
        name: "1-Bit",
        colors: [RGBColor(hex: 0x111111), RGBColor(hex: 0xF5F5F5)],
        isTonal: true
    )

    /// Green phosphor CRT terminal.
    static let greenCRT = Palette(
        name: "Green CRT",
        colors: [
            RGBColor(hex: 0x001800),
            RGBColor(hex: 0x00450F),
            RGBColor(hex: 0x1FBB3A),
            RGBColor(hex: 0x5BFF74),
        ],
        isTonal: true
    )

    /// Amber phosphor CRT terminal.
    static let amberCRT = Palette(
        name: "Amber CRT",
        colors: [
            RGBColor(hex: 0x1A0E00),
            RGBColor(hex: 0x5E3D00),
            RGBColor(hex: 0xD98A00),
            RGBColor(hex: 0xFFC94D),
        ],
        isTonal: true
    )

    /// Warm sepia ramp — old-photograph mood.
    static let sepia = Palette(
        name: "Sepia",
        colors: [
            RGBColor(hex: 0x241606),
            RGBColor(hex: 0x5C3D1E),
            RGBColor(hex: 0x9A6D3F),
            RGBColor(hex: 0xC79A6B),
            RGBColor(hex: 0xEFD9B0),
        ],
        isTonal: true
    )

    // MARK: Full-color palettes (chroma — matched by color distance)

    /// Classic CGA high-intensity mode: black / cyan / magenta / white.
    static let cga = Palette(
        name: "CGA",
        colors: [
            RGBColor(hex: 0x000000),
            RGBColor(hex: 0x55FFFF),
            RGBColor(hex: 0xFF55FF),
            RGBColor(hex: 0xFFFFFF),
        ],
        isTonal: false
    )

    /// The Commodore 64's 16-color home-computer palette.
    static let commodore64 = Palette(
        name: "Commodore 64",
        colors: [
            RGBColor(hex: 0x000000), RGBColor(hex: 0xFFFFFF), RGBColor(hex: 0x880000),
            RGBColor(hex: 0xAAFFEE), RGBColor(hex: 0xCC44CC), RGBColor(hex: 0x00CC55),
            RGBColor(hex: 0x0000AA), RGBColor(hex: 0xEEEE77), RGBColor(hex: 0xDD8855),
            RGBColor(hex: 0x664400), RGBColor(hex: 0xFF7777), RGBColor(hex: 0x333333),
            RGBColor(hex: 0x777777), RGBColor(hex: 0xAAFF66), RGBColor(hex: 0x0088FF),
            RGBColor(hex: 0xBBBBBB),
        ],
        isTonal: false
    )

    /// "Sweetie 16" (GrafxKid) — a punchy, modern 16-color pixel-art palette.
    static let sweetie16 = Palette(
        name: "Sweetie 16",
        colors: [
            RGBColor(hex: 0x1A1C2C), RGBColor(hex: 0x5D275D), RGBColor(hex: 0xB13E53),
            RGBColor(hex: 0xEF7D57), RGBColor(hex: 0xFFCD75), RGBColor(hex: 0xA7F070),
            RGBColor(hex: 0x38B764), RGBColor(hex: 0x257179), RGBColor(hex: 0x29366F),
            RGBColor(hex: 0x3B5DC9), RGBColor(hex: 0x41A6F6), RGBColor(hex: 0x73EFF7),
            RGBColor(hex: 0xF4F4F4), RGBColor(hex: 0x94B0C2), RGBColor(hex: 0x566C86),
            RGBColor(hex: 0x333C57),
        ],
        isTonal: false
    )
}
