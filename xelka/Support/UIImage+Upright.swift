//
//  UIImage+Upright.swift
//  xelka
//
//  Cameras and the photo library hand back images whose pixels are in sensor
//  orientation with a separate `imageOrientation` flag. The engine works on raw
//  CGImage pixels, so we bake the rotation in once here before processing.
//

#if canImport(UIKit)
import UIKit

extension UIImage {
    /// A CGImage with orientation applied, so row 0 is really the top.
    var uprightCGImage: CGImage? {
        // Already up and backed by a CGImage — no redraw needed.
        if imageOrientation == .up, let cg = cgImage { return cg }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let redrawn = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return redrawn.cgImage
    }
}
#endif
