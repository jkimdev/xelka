//
//  CustomPresetTests.swift
//  xelkaTests
//
//  The custom-preset ↔ engine-style conversions that let a saved look reapply
//  across the camera and result screens.
//

import Testing
@testable import xelka

struct CustomPresetTests {

    @Test func asStyleRebuildsTheFullRecipe() {
        let p = CustomPreset(name: "My GB", baseStyleID: "gameboy",
                             ditheringRaw: Dithering.floydSteinberg.rawValue,
                             resolution: 96, contrast: 1.3, saturation: 0.4, brightness: 0.1)
        let s = p.asStyle
        #expect(s.name == "My GB")
        #expect(s.baseID == "gameboy")
        #expect(s.dithering == .floydSteinberg)
        #expect(s.resolution == 96)
        #expect(s.preprocess.contrast == 1.3)
        #expect(s.preprocess.saturation == 0.4)
        #expect(s.preprocess.brightness == 0.1)
        // Palette comes from the base style.
        if case .fixed(let p) = s.quantization {
            #expect(p.name == Palette.gameBoy.name)
        } else {
            Issue.record("expected a fixed palette from the Game Boy base")
        }
    }

    @Test func freeBasePresetIsNotPremium() {
        let p = CustomPreset(name: "x", baseStyleID: "gameboy",
                             ditheringRaw: "ordered", resolution: 128,
                             contrast: 1, saturation: 1, brightness: 0)
        #expect(p.asStyle.isPremium == false)
    }

    @Test func premiumBasePresetInheritsPremium() {
        let p = CustomPreset(name: "x", baseStyleID: "sweetie16",
                             ditheringRaw: "none", resolution: 144,
                             contrast: 1, saturation: 1, brightness: 0)
        #expect(p.asStyle.isPremium == true)
    }

    @Test func captureFromBuiltInStyleUsesItsID() {
        let p = CustomPreset.capture(name: "cap", style: .pico8, dithering: .ordered,
                                     resolution: 100, preprocess: .neutral)
        #expect(p.baseStyleID == "pico8")
        #expect(p.resolution == 100)
    }

    @Test func captureFromCustomStyleRecoversRealBase() {
        // Editing a custom preset then re-saving must trace back to the base,
        // not "custom:…", so the new preset still has a real palette.
        let original = CustomPreset(name: "base c64", baseStyleID: "c64",
                                    ditheringRaw: "ordered", resolution: 128,
                                    contrast: 1, saturation: 1, brightness: 0)
        let editedStyle = original.asStyle            // id == "custom:…", baseID == "c64"
        let resaved = CustomPreset.capture(name: "again", style: editedStyle,
                                           dithering: .floydSteinberg, resolution: 128,
                                           preprocess: .neutral)
        #expect(resaved.baseStyleID == "c64")
    }
}
