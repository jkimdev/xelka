//
//  GalleryView.swift
//  xelka
//
//  Grid of saved pixel-art shots, newest first. Tap for a full-screen look;
//  swipe or long-press to delete.
//

import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PixelShot.createdAt, order: .reverse) private var shots: [PixelShot]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        Group {
            if shots.isEmpty {
                ContentUnavailableView("No shots yet",
                                       systemImage: "square.grid.2x2",
                                       description: Text("Pixelate a photo to start your gallery."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(shots) { shot in
                            NavigationLink { detail(shot) } label: { thumb(shot) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        modelContext.delete(shot)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                    .padding(2)
                }
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func thumb(_ shot: PixelShot) -> some View {
        if let cg = ImageIO.cgImage(from: shot.pngData) {
            PixelArtView(cgImage: cg)
                .aspectRatio(1, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .clipped()
                .background(Color.black)
        } else {
            Color.gray.aspectRatio(1, contentMode: .fill)
        }
    }

    @ViewBuilder
    private func detail(_ shot: PixelShot) -> some View {
        VStack {
            if let cg = ImageIO.cgImage(from: shot.pngData) {
                PixelArtView(cgImage: cg).padding()
            }
            Text(shot.styleName).font(.headline)
            Text(shot.createdAt, format: .dateTime).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .navigationTitle(shot.styleName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
