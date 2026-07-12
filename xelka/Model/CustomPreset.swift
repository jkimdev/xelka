//
//  CustomPreset.swift
//  xelka
//
//  A user-saved look: a built-in palette (the "base") plus the dithering, pixel
//  size, and tone tweaks the user dialed in. Reapplying a preset rebuilds the
//  full engine recipe, so presets carry from the camera through to the result
//  screen. Persisted with SwiftData alongside the gallery.
//

import Foundation
import SwiftData

@Model
final class CustomPreset {
    var id: String
    var name: String
    /// Which built-in style supplies the palette / quantization strategy.
    var baseStyleID: String
    var ditheringRaw: String
    var resolution: Int
    var contrast: Double
    var saturation: Double
    var brightness: Double
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, baseStyleID: String,
         ditheringRaw: String, resolution: Int,
         contrast: Double, saturation: Double, brightness: Double,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.baseStyleID = baseStyleID
        self.ditheringRaw = ditheringRaw
        self.resolution = resolution
        self.contrast = contrast
        self.saturation = saturation
        self.brightness = brightness
        self.createdAt = createdAt
    }
}

extension CustomPreset {
    /// The built-in style this preset draws its palette from (fallback: Game Boy).
    var baseStyle: PixelArtStyle {
        PixelArtStyle.presets.first { $0.id == baseStyleID } ?? .gameBoy
    }

    /// The full engine recipe this preset represents — a ready-to-use style.
    var asStyle: PixelArtStyle {
        let base = baseStyle
        var s = PixelArtStyle(
            id: "custom:\(id)",
            name: name,
            subtitle: "Custom",
            resolution: resolution,
            quantization: base.quantization,
            dithering: Dithering(rawValue: ditheringRaw) ?? base.dithering,
            preprocess: Preprocess(contrast: Float(contrast),
                                   saturation: Float(saturation),
                                   brightness: Float(brightness))
        )
        s.baseID = base.id
        return s
    }

    /// Capture the current editing state as a new preset. `style` may itself be a
    /// custom style — its `baseID` recovers the real built-in base.
    static func capture(name: String, style: PixelArtStyle, dithering: Dithering,
                        resolution: Int, preprocess: Preprocess) -> CustomPreset {
        CustomPreset(
            name: name,
            baseStyleID: style.baseID ?? style.id,
            ditheringRaw: dithering.rawValue,
            resolution: resolution,
            contrast: Double(preprocess.contrast),
            saturation: Double(preprocess.saturation),
            brightness: Double(preprocess.brightness)
        )
    }
}
