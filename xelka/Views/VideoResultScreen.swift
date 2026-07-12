//
//  VideoResultScreen.swift
//  xelka
//
//  Plays back a freshly recorded pixel-art clip on a loop and lets you save it to
//  the photo library, share the MP4, or export a GIF. The video is already
//  pixelated (recorded straight off the live filter), so there's nothing to
//  re-process here.
//

#if os(iOS)
import SwiftUI
import AVKit
import UIKit

struct VideoResultScreen: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    @State private var player: AVPlayer
    @State private var shareItem: ShareItem?
    @State private var isExportingGIF = false
    @State private var didSave = false

    /// Identifiable wrapper so a shareable file URL can drive `.sheet(item:)`.
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: player)
                .onAppear { startLooping() }
                .onDisappear { player.pause() }
            controls
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Retake") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { save() } label: {
                    Label(didSave ? "Saved" : "Save",
                          systemImage: didSave ? "checkmark" : "square.and.arrow.down")
                }
                .disabled(didSave)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Button { shareItem = ShareItem(url: url) } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            Button(action: shareGIF) {
                Group {
                    if isExportingGIF {
                        ProgressView().tint(.white)
                    } else {
                        Label("GIF", systemImage: "photo.stack")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isExportingGIF)
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }

    // MARK: Actions

    private func startLooping() {
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }

    private func save() {
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
        didSave = true
    }

    private func shareGIF() {
        isExportingGIF = true
        Task {
            let gif = await GIFExporter.make(from: url)
            isExportingGIF = false
            if let gif { shareItem = ShareItem(url: gif) }
        }
    }
}
#endif
