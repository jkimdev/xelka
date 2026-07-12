//
//  ResultModelTests.swift
//  xelkaTests
//
//  Covers the tone-adjustment override state machine that backs the result
//  screen's contrast/saturation/brightness sliders: overrides seed from the
//  style, track when they diverge, reset, and reseed when the style changes.
//

import Testing
import CoreGraphics
@testable import xelka

@MainActor
struct ResultModelTests {

    private func model(_ style: PixelArtStyle) -> ResultModel {
        ResultModel(source: EngineTests.solid((120, 120, 120), w: 64, h: 64), style: style)
    }

    @Test func adjustmentsSeedFromStyleDefaults() {
        let m = model(.gameBoy)
        #expect(m.preprocess.contrast == PixelArtStyle.gameBoy.preprocess.contrast)
        #expect(m.preprocess.saturation == PixelArtStyle.gameBoy.preprocess.saturation)
        #expect(m.hasCustomAdjustments == false)
    }

    @Test func movingASliderMarksCustomThenResetRestores() {
        let m = model(.gameBoy)
        m.setContrast(1.5)
        #expect(m.preprocess.contrast == 1.5)
        #expect(m.hasCustomAdjustments == true)

        m.resetAdjustments()
        #expect(m.hasCustomAdjustments == false)
        #expect(m.preprocess.contrast == PixelArtStyle.gameBoy.preprocess.contrast)
    }

    @Test func selectingAStyleReseedsAdjustments() {
        let m = model(.gameBoy)
        m.setSaturation(1.9)
        #expect(m.hasCustomAdjustments == true)

        m.select(.pico8)
        #expect(m.preprocess.saturation == PixelArtStyle.pico8.preprocess.saturation)
        #expect(m.hasCustomAdjustments == false)
    }

    @Test func seedsPreprocessFromPreCaptureStyle() {
        // The camera folds its tone tweaks into the style it hands off; the
        // result model must start from them, not the style's authored defaults.
        var s = PixelArtStyle.gameBoy
        s.preprocess = Preprocess(contrast: 1.4, saturation: 0.3, brightness: 0.2)
        let m = ResultModel(source: EngineTests.solid((10, 10, 10), w: 64, h: 64), style: s)
        #expect(m.preprocess.contrast == 1.4)
        #expect(m.preprocess.saturation == 0.3)
        #expect(m.preprocess.brightness == 0.2)
    }

    @Test func seedsResolutionFromPreCaptureOverride() {
        // The camera passes its live style with a chosen pixel size folded in;
        // the result model must start there, not at the style's authored default.
        var s = PixelArtStyle.gameBoy
        s.resolutionOverride = 96
        let m = ResultModel(source: EngineTests.solid((10, 10, 10), w: 64, h: 64), style: s)
        #expect(m.resolution == 96)
    }

    @Test func brightnessOverrideIsIndependent() {
        let m = model(.modernClean)
        m.setBrightness(0.25)
        #expect(m.preprocess.brightness == 0.25)
        // Only brightness moved; contrast/saturation stay at style defaults.
        #expect(m.preprocess.contrast == PixelArtStyle.modernClean.preprocess.contrast)
        #expect(m.hasCustomAdjustments == true)
    }
}
