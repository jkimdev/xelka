//
//  Watermark.swift
//  xelka
//
//  Stamps a small "xelka" wordmark onto exported art for free-tier users. Pro
//  exports skip this entirely. Applied at bake time (the large export image),
//  never to the on-screen preview, so the watermark scales with the saved file.
//

#if canImport(UIKit)
import UIKit

enum Watermark {
    /// Return a copy of `cgImage` with the wordmark drawn into the bottom-right
    /// corner. Same pixel dimensions in, same out.
    static func stamp(_ cgImage: CGImage) -> CGImage {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let size = CGSize(width: width, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1          // pixels are 1:1 with the CGImage
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let stamped = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))

            let text = "xelka" as NSString
            let fontSize = max(14, height * 0.045)
            let inset = height * 0.03
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                // Negative stroke = fill + outline, keeps it legible on any art.
                .strokeColor: UIColor.black.withAlphaComponent(0.55),
                .strokeWidth: -3.0,
            ]
            let textSize = text.size(withAttributes: attrs)
            let origin = CGPoint(x: width - textSize.width - inset,
                                 y: height - textSize.height - inset)
            text.draw(at: origin, withAttributes: attrs)
        }
        return stamped.cgImage ?? cgImage
    }
}
#endif
