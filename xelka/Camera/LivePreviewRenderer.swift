//
//  LivePreviewRenderer.swift
//  xelka
//
//  Receives camera frames, runs the GPU pixel-art filter, and draws the result
//  into an MTKView — the standard real-time Core-Image-over-Metal camera path.
//  The selected style can change at any time (thread-safe) so tapping a chip
//  restyles the live feed instantly.
//
//  Frames arrive on the capture queue; we only stash the latest processed image
//  there. The actual Metal present happens in `draw(in:)` on the MAIN thread,
//  driven by the view's display link — grabbing `currentDrawable` off the main
//  thread returns nil on device (a black preview), so this split is required.
//

#if os(iOS)
import AVFoundation
import CoreImage
import MetalKit

nonisolated final class LivePreviewRenderer: NSObject, MTKViewDelegate,
                                             AVCaptureVideoDataOutputSampleBufferDelegate {

    let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext
    private let filter: PixelLiveFilter
    private let drawColorSpace = CGColorSpaceCreateDeviceRGB()

    // Written on the capture queue / main, read in draw(in:) on main.
    private let lock = NSLock()
    private var _style: PixelArtStyle = .gameBoy
    private var _latest: CIImage?

    // Recording state, guarded separately so frame delivery never blocks on it.
    private let recorderLock = NSLock()
    private var recorder: VideoRecorder?

    var style: PixelArtStyle {
        get { lock.lock(); defer { lock.unlock() }; return _style }
        set { lock.lock(); _style = newValue; lock.unlock() }
    }

    // MARK: Recording

    /// Begin encoding the pixel-art feed to an MP4. Frames captured from now until
    /// `stopRecording()` are appended.
    func startRecording() {
        let rec = VideoRecorder(ciContext: ciContext)
        recorderLock.lock(); recorder = rec; recorderLock.unlock()
    }

    /// Stop and finalize the clip. Returns the file URL, or nil if nothing was
    /// captured.
    func stopRecording() async -> URL? {
        recorderLock.lock(); let rec = recorder; recorder = nil; recorderLock.unlock()
        return await rec?.finish()
    }

    override init() {
        let dev = MTLCreateSystemDefaultDevice()
        let queue = dev?.makeCommandQueue()
        self.device = dev
        self.commandQueue = queue
        if let queue {
            self.ciContext = CIContext(mtlCommandQueue: queue, options: [.cacheIntermediates: false])
        } else {
            self.ciContext = CIContext(options: nil)
        }
        self.filter = PixelLiveFilter(context: ciContext)
        super.init()
    }

    /// Wire up the MTKView to render continuously from its display link.
    func attach(_ mtkView: MTKView) {
        mtkView.device = device
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.backgroundColor = .black
        mtkView.isPaused = false            // free-running; draw(in:) fires on main
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 30
        self.view = mtkView
    }

    private weak var view: MTKView?

    // MARK: Frame delivery (capture queue) — just stash the latest frame.

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let processed = filter.apply(to: source, style: style)
        lock.lock(); _latest = processed; lock.unlock()

        recorderLock.lock(); let rec = recorder; recorderLock.unlock()
        rec?.append(processed, at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }

    // MARK: MTKViewDelegate (main thread)

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        lock.lock(); let image = _latest; lock.unlock()
        guard let image, let commandQueue,
              let drawable = view.currentDrawable else { return }
        let size = view.drawableSize
        guard size.width > 1, size.height > 1 else { return }

        autoreleasepool {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            let filled = aspectFill(image, into: size)
            ciContext.render(filled, to: drawable.texture, commandBuffer: commandBuffer,
                             bounds: CGRect(origin: .zero, size: size), colorSpace: drawColorSpace)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    /// Scale to cover `size`, center-crop the overflow.
    private func aspectFill(_ image: CIImage, into size: CGSize) -> CIImage {
        let ext = image.extent
        guard ext.width > 0, ext.height > 0 else { return image }
        let scale = max(size.width / ext.width, size.height / ext.height)
        let tx = (size.width - ext.width * scale) / 2
        let ty = (size.height - ext.height * scale) / 2
        return image
            .transformed(by: CGAffineTransform(translationX: -ext.minX, y: -ext.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: tx, y: ty))
            .cropped(to: CGRect(origin: .zero, size: size))
    }
}
#endif
