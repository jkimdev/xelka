//
//  VideoRecorderTests.swift
//  xelkaTests
//
//  Exercises the video-encoding path without a camera: feed the recorder a stream
//  of synthetic CIImages and confirm it produces a playable MP4, then that the MP4
//  converts to a valid GIF.
//

#if os(iOS)
import Testing
import AVFoundation
import CoreImage
import CoreGraphics
import Foundation
@testable import xelka

struct VideoRecorderTests {

    @Test func recordsFramesIntoPlayableMP4AndGIF() async throws {
        let ctx = CIContext()
        let recorder = VideoRecorder(ciContext: ctx)
        let frame = CGRect(x: 0, y: 0, width: 240, height: 240)

        // 15 solid-color frames at 30fps → ~0.5s clip.
        for i in 0..<15 {
            let color = CIColor(red: CGFloat(i) / 15, green: 0.2, blue: 0.8)
            let image = CIImage(color: color).cropped(to: frame)
            recorder.append(image, at: CMTime(value: CMTimeValue(i), timescale: 30))
        }

        let url = try #require(await recorder.finish(), "recorder should produce a file")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty)
        let duration = try await asset.load(.duration)
        #expect(CMTimeGetSeconds(duration) > 0)

        // The MP4 converts to a non-empty GIF (magic bytes "GIF").
        let gifURL = try #require(await GIFExporter.make(from: url, fps: 8, maxLongEdge: 120),
                                  "GIF export should succeed")
        let gifData = try Data(contentsOf: gifURL)
        #expect(gifData.count > 0)
        #expect(gifData.prefix(3) == Data("GIF".utf8))

        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: gifURL)
    }

    @Test func finishWithoutFramesReturnsNil() async {
        let recorder = VideoRecorder(ciContext: CIContext())
        let url = await recorder.finish()
        #expect(url == nil)
    }
}
#endif
