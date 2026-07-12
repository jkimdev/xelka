//
//  ResultScreen.swift
//  xelka
//
//  Shows the pixelated result and lets you switch styles / dithering / pixel size
//  live on the same source, then save to the gallery (and optionally the photo
//  album) or share it straight to another app.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ResultScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model: ResultModel
    @State private var didSave = false

    #if canImport(UIKit)
    @State private var shareImage: ShareImage?

    /// Identifiable wrapper so a baked export image can drive `.sheet(item:)`.
    private struct ShareImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    #endif

    init(source: CGImage, initialStyle: PixelArtStyle) {
        _model = State(initialValue: ResultModel(source: source, style: initialStyle))
    }

    var body: some View {
        content
        #if canImport(UIKit)
            .sheet(item: $shareImage) { ShareSheet(items: [$0.image]) }
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            preview
            controls
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Retake") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { share() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(model.output == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Label(didSave ? "Saved" : "Save", systemImage: didSave ? "checkmark" : "square.and.arrow.down")
                }
                .disabled(model.output == nil || didSave)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            if let out = model.output {
                PixelArtView(cgImage: out)
                    .padding(16)
            } else {
                ProgressView().tint(.white)
            }
            if model.isProcessing && model.output != nil {
                ProgressView()
                    .tint(.white)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PixelArtStyle.presets) { style in
                        StyleChip(style: style, isSelected: style.id == model.style.id) {
                            didSave = false
                            model.select(style)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Picker("Dithering", selection: ditheringBinding) {
                ForEach(Dithering.allCases) { d in
                    Text(d.label).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            pixelSizeSlider
        }
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    /// Chunky ← → fine. Drives the engine's long-edge resolution live.
    private var pixelSizeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
            Slider(value: resolutionBinding, in: 48...256, step: 8)
                .tint(.white)
            Image(systemName: "square.grid.4x3.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
    }

    private var ditheringBinding: Binding<Dithering> {
        Binding(get: { model.dithering }, set: { didSave = false; model.setDithering($0) })
    }

    private var resolutionBinding: Binding<Double> {
        Binding(get: { Double(model.resolution) },
                set: { didSave = false; model.setResolution(Int($0)) })
    }

    // MARK: Save / Share

    private func save() {
        Task {
            guard let baked = await model.bakedForExport(),
                  let png = ImageIO.png(from: baked) else { return }
            let shot = PixelShot(styleID: model.style.id, styleName: model.style.name, pngData: png)
            modelContext.insert(shot)
            ImageIO.saveToPhotos(baked)
            didSave = true
        }
    }

    private func share() {
        Task {
            guard let baked = await model.bakedForExport() else { return }
            #if canImport(UIKit)
            shareImage = ShareImage(image: UIImage(cgImage: baked))
            #endif
        }
    }
}
