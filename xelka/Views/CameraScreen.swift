//
//  CameraScreen.swift
//  xelka
//
//  The home screen: live camera behind a style bar and shutter. Capture (or
//  import from Photos) produces a source image that opens the result screen.
//

import SwiftUI
import PhotosUI
import Combine

/// Identifiable wrapper so a captured CGImage can drive `.fullScreenCover(item:)`.
struct SourceImage: Identifiable {
    let id = UUID()
    let cgImage: CGImage
}

/// Identifiable wrapper so a recorded clip URL can drive `.fullScreenCover(item:)`.
struct VideoResult: Identifiable {
    let id = UUID()
    let url: URL
}

/// Whether the shutter takes a still or records a clip.
enum CaptureMode { case photo, video }

struct CameraScreen: View {
    @Environment(ProStore.self) private var store
    @State private var selectedStyle: PixelArtStyle = .gameBoy
    @State private var pending: SourceImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var captureMode: CaptureMode = .photo
    @State private var showPaywall = false

    #if os(iOS)
    @State private var camera = CameraController()
    @State private var renderer = LivePreviewRenderer()
    @State private var isRecording = false
    @State private var recordSeconds = 0
    @State private var pendingVideo: VideoResult?
    #endif

    var body: some View {
        ZStack {
            background
            overlay
        }
        .navigationTitle("xelka")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.isPro {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPaywall = true } label: {
                        Label("Pro", systemImage: "crown.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(.yellow)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { GalleryView() } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #if os(iOS)
        .task {
            await camera.start()
            if case .running = camera.status {
                camera.attachVideoDelegate(renderer)
            }
            renderer.style = selectedStyle
        }
        .onChange(of: selectedStyle.id) { _, _ in renderer.style = selectedStyle }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRecording { recordSeconds += 1 }
        }
        .onDisappear { camera.stop() }
        .fullScreenCover(item: $pendingVideo) { vid in
            NavigationStack {
                VideoResultScreen(url: vid.url)
            }
        }
        #endif
        .onChange(of: pickerItem) { _, item in loadPicked(item) }
        .fullScreenCover(item: $pending) { src in
            NavigationStack {
                ResultScreen(source: src.cgImage, initialStyle: selectedStyle)
            }
        }
    }

    // MARK: Background (camera / placeholder)

    @ViewBuilder
    private var background: some View {
        #if os(iOS)
        switch camera.status {
        case .running:
            MetalCameraView(renderer: renderer).ignoresSafeArea()
        case .denied:
            placeholder(text: "Camera access is off.\nImport a photo below, or enable the camera in Settings.")
        case .failed(let msg):
            placeholder(text: msg)
        default:
            placeholder(text: "Starting camera…")
        }
        #else
        placeholder(text: "Import a photo to pixelate.")
        #endif
    }

    private func placeholder(text: String) -> some View {
        ZStack {
            Color.black
            VStack(spacing: 12) {
                Image(systemName: "camera.fill").font(.largeTitle)
                Text(text).multilineTextAlignment(.center).font(.callout)
            }
            .foregroundStyle(.secondary)
            .padding()
        }
        .ignoresSafeArea()
    }

    // MARK: Foreground controls

    private var overlay: some View {
        VStack {
            #if os(iOS)
            if isRecording {
                recordingPill.padding(.top, 8)
            }
            #endif
            Spacer()
            #if os(iOS)
            modePicker
            #endif
            styleBar
            shutterRow
                .padding(.bottom, 8)
        }
    }

    private var styleBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PixelArtStyle.presets) { style in
                    let locked = style.isPremium && !store.isPro
                    StyleChip(style: style, isSelected: style.id == selectedStyle.id, locked: locked) {
                        if locked { showPaywall = true } else { selectedStyle = style }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private var shutterRow: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.stack")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(maxWidth: .infinity)

            shutterButton
                .frame(maxWidth: .infinity)

            #if os(iOS)
            Button { camera.flipCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .frame(maxWidth: .infinity)
            .disabled(!canCapture)
            .opacity(canCapture ? 1 : 0.4)
            #else
            // Symmetry spacer so the shutter stays centered.
            Color.clear.frame(width: 52, height: 52).frame(maxWidth: .infinity)
            #endif
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var shutterButton: some View {
        Button(action: shutterTapped) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4).frame(width: 72, height: 72)
                shutterCore
                if isCapturing {
                    ProgressView().tint(.black)
                }
            }
        }
        .disabled(isCapturing || !canCapture)
        .opacity(canCapture ? 1 : 0.4)
    }

    /// The inner shape: white for photo, red for video, a red square while recording.
    @ViewBuilder
    private var shutterCore: some View {
        #if os(iOS)
        if captureMode == .video {
            if isRecording {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.red).frame(width: 28, height: 28)
            } else {
                Circle().fill(.red).frame(width: 58, height: 58)
            }
        } else {
            Circle().fill(.white).frame(width: 58, height: 58)
        }
        #else
        Circle().fill(.white).frame(width: 58, height: 58)
        #endif
    }

    private func shutterTapped() {
        #if os(iOS)
        if captureMode == .video { toggleRecord() } else { capture() }
        #else
        capture()
        #endif
    }

    private var canCapture: Bool {
        #if os(iOS)
        if case .running = camera.status { return true }
        return false
        #else
        return false
        #endif
    }

    #if os(iOS)
    private var modePicker: some View {
        Picker("Mode", selection: modeBinding) {
            Text("Photo").tag(CaptureMode.photo)
            Label("Video", systemImage: store.isPro ? "video" : "lock.fill")
                .tag(CaptureMode.video)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
        .padding(.bottom, 8)
        .disabled(isRecording)
    }

    /// Selecting Video as a free user opens the paywall instead of switching.
    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { captureMode },
            set: { newMode in
                if newMode == .video && !store.isPro {
                    showPaywall = true
                } else {
                    captureMode = newMode
                }
            }
        )
    }

    private var recordingPill: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Text(timeString(recordSeconds))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    #endif

    // MARK: Actions

    private func capture() {
        #if os(iOS)
        isCapturing = true
        Task {
            let cg = await camera.capturePhoto()
            isCapturing = false
            if let cg { pending = SourceImage(cgImage: cg) }
        }
        #endif
    }

    #if os(iOS)
    private func toggleRecord() {
        guard canCapture else { return }
        if isRecording {
            isRecording = false
            Task {
                let url = await renderer.stopRecording()
                if let url { pendingVideo = VideoResult(url: url) }
            }
        } else {
            recordSeconds = 0
            renderer.startRecording()
            isRecording = true
        }
    }
    #endif

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            #if canImport(UIKit)
            if let cg = UIImage(data: data)?.uprightCGImage {
                pending = SourceImage(cgImage: cg)
            }
            #endif
            pickerItem = nil
        }
    }
}
