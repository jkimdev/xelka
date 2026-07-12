//
//  VideoRecorder.swift
//  xelka
//
//  Encodes the stream of already-pixelated live-preview frames straight into an
//  MP4 on disk. The live filter has already done the work, so recording is just
//  "render each CIImage into a pixel buffer and append it" — preview and the
//  saved clip are guaranteed identical. Video-only, no audio: these are short,
//  silent aesthetic clips (and it avoids a microphone-permission prompt).
//
//  Threading: `append` is called on the capture queue and `finish` from the main
//  actor. Both take `lock`, so an in-flight append completes before finalizing
//  and no frame is appended after the file is closed.
//

#if os(iOS)
import AVFoundation
import CoreImage

final class VideoRecorder: @unchecked Sendable {
    private let ciContext: CIContext
    private let url: URL

    private let lock = NSLock()
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var started = false
    private var finished = false

    init(ciContext: CIContext) {
        self.ciContext = ciContext
        self.url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xelka-\(UUID().uuidString).mp4")
    }

    /// Append one filtered frame at its capture timestamp, configuring the writer
    /// lazily from the first frame's dimensions.
    func append(_ image: CIImage, at time: CMTime) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }

        let w = Int(image.extent.width) & ~1   // H.264 needs even dimensions
        let h = Int(image.extent.height) & ~1
        guard w > 0, h > 0 else { return }

        if writer == nil, !configure(width: w, height: h) { return }
        guard let writer, let input, let adaptor, writer.status == .writing else { return }

        if !started {
            started = true
            writer.startSession(atSourceTime: time)
        }
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }

        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer else { return }

        // The filtered image's extent origin isn't necessarily zero; move it to
        // the buffer's origin before rendering.
        let framed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX,
                                                             y: -image.extent.minY))
        ciContext.render(framed, to: buffer)
        adaptor.append(buffer, withPresentationTime: time)
    }

    /// Finalize the file. Returns nil if nothing was actually recorded.
    func finish() async -> URL? {
        lock.lock()
        finished = true
        let writer = self.writer
        let input = self.input
        let didStart = started
        lock.unlock()

        guard let writer, let input, didStart, writer.status == .writing else { return nil }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    /// Build the writer + input + pixel-buffer adaptor for `width`×`height`.
    /// Caller holds `lock`.
    private func configure(width: Int, height: Int) -> Bool {
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ])
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        return true
    }
}
#endif
