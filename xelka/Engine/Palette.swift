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
}
