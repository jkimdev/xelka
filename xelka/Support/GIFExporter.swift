//
//  GIFExporter.swift
//  xelka
//
//  Turns a recorded pixel-art MP4 into an animated GIF for places that want one
//  (Twitter/X, chat). We sample the video at a modest frame rate and long edge so
//  the file stays shareable — pixel blocks are already large, so the downscale
//  keeps the look while cutting size.
//

#if os(iOS)
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum GIFExporter {
    /// Sample `fps` frames per second from `videoURL` and write a looping GIF whose
    /// long edge is at most `maxLongEdge`. Returns a temp `.gif` URL, or nil on
    /// failure.
    static func make(from videoURL: URL, fps: Double = 12, maxLongEdge: CGFloat = 480) async -> URL? {
        let asset = AVURLAsset(url: videoURL)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds > 0, fps > 0 else { return nil }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: maxLongEdge, height: maxLongEdge)

        let frameCount = max(1, Int(seconds * fps))
        let delay = 1.0 / fps

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xelka-\(UUID().uuidString).gif")
        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { return nil }

        let fileProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(dest, fileProps as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay]]

        var wrote = 0
        for i in 0..<frameCount {
            let t = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
            guard let cg = try? await generator.image(at: t).image else { continue }
            CGImageDestinationAddImage(dest, cg, frameProps as CFDictionary)
            wrote += 1
        }
        guard wrote > 0, CGImageDestinationFinalize(dest) else { return nil }
        return outURL
    }
}
#endif
