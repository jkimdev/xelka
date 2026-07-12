//
//  CameraController.swift
//  xelka
//
//  A thin wrapper over AVCaptureSession: permission, live preview session, and
//  a single async still capture that hands back an up-oriented CGImage ready
//  for the pixel-art engine. iOS only — other platforms use the photo picker.
//

#if os(iOS)
import AVFoundation
import UIKit
import Observation

@MainActor
@Observable
final class CameraController: NSObject {

    enum Status: Equatable {
        case idle, configuring, running, denied, failed(String)
    }

    private(set) var status: Status = .idle

    /// The session the preview layer renders. Configured on `sessionQueue`.
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.jimmythegenius.xelka.camera")
    private let videoQueue = DispatchQueue(label: "com.jimmythegenius.xelka.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var activeDelegate: PhotoCaptureDelegate?

    /// The live camera input. Only ever read/written on `sessionQueue`, so it's
    /// `nonisolated(unsafe)` — that serial queue provides the synchronization.
    private nonisolated(unsafe) var deviceInput: AVCaptureDeviceInput?

    /// Which camera is live. The UI observes this to update the flip button; the
    /// actual input swap happens on `sessionQueue` in `flipCamera()`.
    private(set) var cameraPosition: AVCaptureDevice.Position = .back

    // MARK: Lifecycle

    /// Ask for permission (if needed) and wire up input + output. Safe to call
    /// repeatedly; it configures only once.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { status = .denied; return }
        default:
            status = .denied
            return
        }

        if session.isRunning { status = .running; return }
        status = .configuring
        await configureAndRun()
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() async {
        let result: Result<Void, CameraError> = await withCheckedContinuation { cont in
            sessionQueue.async { [self] in
                cont.resume(returning: configureLocked())
            }
        }
        switch result {
        case .success:
            sessionQueue.async { [session] in session.startRunning() }
            status = .running
        case .failure(let err):
            status = .failed(err.message)
        }
    }

    /// Runs on `sessionQueue`. Builds the graph once.
    nonisolated private func configureLocked() -> Result<Void, CameraError> {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = Self.device(for: .back) else {
            return .failure(.init(message: "No camera available"))
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return .failure(.init(message: "Can't add camera input")) }
            session.addInput(input)
            deviceInput = input
        } catch {
            return .failure(.init(message: error.localizedDescription))
        }

        guard session.canAddOutput(photoOutput) else { return .failure(.init(message: "Can't add photo output")) }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Video frames feed the live pixel-art preview.
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        applyConnectionSettings(mirrored: false)
        return .success(())
    }

    /// The wide-angle camera for `position`, falling back to any device for the
    /// back camera (front has no such fallback).
    nonisolated private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? (position == .back ? AVCaptureDevice.default(for: .video) : nil)
    }

    /// Portrait-up preview buffers, plus mirroring on both outputs when the front
    /// camera is live so the preview and the saved selfie read like a mirror.
    nonisolated private func applyConnectionSettings(mirrored: Bool) {
        if let vconn = videoOutput.connection(with: .video) {
            if vconn.isVideoRotationAngleSupported(90) { vconn.videoRotationAngle = 90 }
            if vconn.isVideoMirroringSupported {
                vconn.automaticallyAdjustsVideoMirroring = false
                vconn.isVideoMirrored = mirrored
            }
        }
        // Stills keep their existing EXIF-based orientation; we only mirror the
        // front camera so the saved photo matches what the user framed.
        if let pconn = photoOutput.connection(with: .video), pconn.isVideoMirroringSupported {
            pconn.automaticallyAdjustsVideoMirroring = false
            pconn.isVideoMirrored = mirrored
        }
    }

    /// Swap between the back and front cameras on the running session.
    func flipCamera() {
        guard case .running = status else { return }
        let target: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
        cameraPosition = target
        sessionQueue.async { [self] in
            session.beginConfiguration()
            let previous = deviceInput
            if let previous { session.removeInput(previous) }
            if let device = Self.device(for: target),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                deviceInput = input
            } else if let previous {
                session.addInput(previous) // revert if the swap failed
            }
            applyConnectionSettings(mirrored: target == .front)
            session.commitConfiguration()
        }
    }

    /// Route live camera frames to `delegate` (the Metal renderer).
    func attachVideoDelegate(_ delegate: any AVCaptureVideoDataOutputSampleBufferDelegate) {
        sessionQueue.async { [videoOutput, videoQueue] in
            videoOutput.setSampleBufferDelegate(delegate, queue: videoQueue)
        }
    }

    // MARK: Capture

    /// Take a photo and return it as an up-oriented CGImage.
    func capturePhoto() async -> CGImage? {
        guard case .running = status else { return nil }
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality

        return await withCheckedContinuation { cont in
            let delegate = PhotoCaptureDelegate { [weak self] cgImage in
                cont.resume(returning: cgImage)
                self?.activeDelegate = nil
            }
            // Keep the delegate alive until AVFoundation calls back.
            self.activeDelegate = delegate
            sessionQueue.async { [photoOutput] in
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private struct CameraError: Error { let message: String }
}

/// Bridges AVFoundation's delegate callback (on a private queue) into a single
/// closure delivering an up-oriented CGImage. Nonisolated on purpose.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (CGImage?) -> Void

    init(completion: @escaping (CGImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image.uprightCGImage)
    }
}
#endif
