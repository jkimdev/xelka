//
//  AdaptivePalette.swift
//  xelka
//
//  Median-cut color quantization. The "Modern Clean" style has no fixed
//  palette — instead we derive a compact palette *from the photo itself* so the
//  result keeps the original mood while snapping to crisp flat color blocks.
//

import Foundation

enum AdaptivePalette {

    /// Build a palette of at most `maxColors` colors from an already-downsampled
    /// pixel buffer. `maxColors` is rounded down to the nearest power of two by
    /// the classic median-cut split, so pass 16 / 32 / 64 for exact counts.
    static func build(from pixels: [RGBColor], maxColors: Int) -> Palette {
        guard !pixels.isEmpty else {
            return Palette(name: "Adaptive", colors: [RGBColor(0, 0, 0)], isTonal: false)
        }

        var boxes = [Box(pixels: pixels)]

        // Split the box with the largest color range until we hit the target,
        // or until nothing can be split further.
        while boxes.count < maxColors {
            // Pick the splittable box with the widest channel spread. A box with
            // zero volume (all pixels identical) carries no more colors, so we
            // skip it — a flat image yields a small palette, not padded duplicates.
            guard let idx = boxes.enumerated()
                .filter({ $0.element.pixels.count > 1 && $0.element.volume > 0 })
                .max(by: { $0.element.volume < $1.element.volume })?.offset
            else { break }

            let (a, b) = boxes[idx].split()
            boxes.remove(at: idx)
            boxes.append(a)
            boxes.append(b)
        }

        let colors = boxes.map { $0.average }
        return Palette(name: "Adaptive", colors: colors, isTonal: false)
    }

    /// One region of color space holding the pixels that fall inside it.
    private struct Box {
        var pixels: [RGBColor]

        // Per-channel extent of the pixels in this box.
        var rRange: Float { range(\.r) }
        var gRange: Float { range(\.g) }
        var bRange: Float { range(\.b) }

        /// Weighted by human sensitivity so we split green before blue — matches
        /// how the eye resolves detail and avoids banding in foliage/skin.
        var volume: Float {
            rRange * 0.30 + gRange * 0.59 + bRange * 0.11
        }

        private func range(_ kp: KeyPath<RGBColor, Float>) -> Float {
            var lo = Float.greatestFiniteMagnitude
            var hi = -Float.greatestFiniteMagnitude
            for p in pixels {
                let v = p[keyPath: kp]
                if v < lo { lo = v }
                if v > hi { hi = v }
            }
            return hi - lo
        }

        var average: RGBColor {
            var r: Float = 0, g: Float = 0, b: Float = 0
            for p in pixels { r += p.r; g += p.g; b += p.b }
            let n = Float(pixels.count)
            return RGBColor(r: r / n, g: g / n, b: b / n)
        }

        /// Split along the longest axis at the median, so each half holds an
        /// equal share of pixels (the "median" in median cut).
        func split() -> (Box, Box) {
            let kp = longestAxis()
            let sorted = pixels.sorted { $0[keyPath: kp] < $1[keyPath: kp] }
            let mid = sorted.count / 2
            return (Box(pixels: Array(sorted[..<mid])),
                    Box(pixels: Array(sorted[mid...])))
        }

        private func longestAxis() -> KeyPath<RGBColor, Float> {
            let r = rRange, g = gRange, b = bRange
            if g >= r && g >= b { return \.g }
            if r >= g && r >= b { return \.r }
            return \.b
        }
    }
}
