//
//  DitherKernelTests.swift
//  xelkaTests
//
//  Verifies the live GPU dither path: the Bayer Metal kernel actually loads
//  from the app's default.metallib and breaks a flat tone into multiple palette
//  shades — while a no-dither style stays flat. Runs in the simulator; no camera
//  needed since we feed a synthetic CIImage.
//

import Testing
import CoreImage
@testable import xelka

struct DitherKernelTests {

    private func flatGray(_ size: Int) -> CIImage {
        CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    private func distinctColors(of image: CIImage, context: CIContext) -> Int {
        let ext = image.extent
        let w = Int(ext.width), h = Int(ext.height)
        guard w > 0, h > 0 else { return 0 }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        context.render(image, toBitmap: &buf, rowBytes: w * 4,
                       bounds: CGRect(x: 0, y: 0, width: w, height: h),
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        var set = Set<UInt32>()
        for i in 0..<(w * h) {
            let o = i * 4
            set.insert(UInt32(buf[o]) << 16 | UInt32(buf[o + 1]) << 8 | UInt32(buf[o + 2]))
        }
        return set.count
    }

    @Test func orderedDitherAddsShadesOverFlatTone() {
        #expect(PixelLiveFilter.isDitherKernelAvailable, "\(PixelLiveFilter.ditherLoadDiagnostic)")

        let ctx = CIContext(options: nil)
        let filter = PixelLiveFilter(context: ctx)
        let input = flatGray(256)

        // Game Boy uses ordered dither: a flat tone must break into >1 shade.
        let dithered = filter.apply(to: input, style: .gameBoy)
        let ditheredCount = distinctColors(of: dithered, context: ctx)

        // Modern Clean has no dither: a flat tone quantizes to a single color.
        let flat = filter.apply(to: input, style: .modernClean)
        let flatCount = distinctColors(of: flat, context: ctx)

        #expect(ditheredCount >= 2)      // the kernel loaded and did something
        #expect(ditheredCount > flatCount) // dithering demonstrably adds shades
    }
}
