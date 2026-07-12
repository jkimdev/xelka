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
    @Environment(ProStore.self) private var store

    @State private var model: ResultModel
    @State private var didSave = false
    @State private var showPaywall = false
    @State private var showAdjust = false

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
            .sheet(isPresented: $showPaywall) { PaywallView() }
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
                        let locked = style.isPremium && !store.isPro
                        StyleChip(style: style, isSelected: style.id == model.style.id, locked: locked) {
                            if locked {
                                showPaywall = true
                            } else {
                                didSave = false
                                model.select(style)
                            }
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

            adjustments

            if !store.isPro {
                Button { showPaywall = true } label: {
                    Label("Remove watermark with Pro", systemImage: "crown.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(.yellow)
            }
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

    // MARK: Tone adjustments (contrast / saturation / brightness)

    /// Collapsible tone controls. Hidden by default so the picker stays clean;
    /// a dot marks the header when the sliders are off the style's defaults.
    private var adjustments: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAdjust.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Label("Adjust", systemImage: "slider.horizontal.3")
                    if model.hasCustomAdjustments {
                        Circle().fill(.yellow).frame(width: 6, height: 6)
                    }
                    Spacer()
                    Image(systemName: showAdjust ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if showAdjust {
                adjustSlider(icon: "circle.righthalf.filled", value: contrastBinding, in: 0.5...2.0)
                adjustSlider(icon: "drop.halffull", value: saturationBinding, in: 0...2.0)
                adjustSlider(icon: "sun.max", value: brightnessBinding, in: -0.5...0.5)

                Button("Reset") { didSave = false; model.resetAdjustments() }
                    .font(.caption.weight(.semibold))
                    .tint(.white)
                    .disabled(!model.hasCustomAdjustments)
            }
        }
    }

    private func adjustSlider(icon: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 20)
            Slider(value: value, in: range).tint(.white)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
    }

    private var contrastBinding: Binding<Double> {
        Binding(get: { Double(model.preprocess.contrast) },
                set: { didSave = false; model.setContrast(Float($0)) })
    }

    private var saturationBinding: Binding<Double> {
        Binding(get: { Double(model.preprocess.saturation) },
                set: { didSave = false; model.setSaturation(Float($0)) })
    }

    private var brightnessBinding: Binding<Double> {
        Binding(get: { Double(model.preprocess.brightness) },
                set: { didSave = false; model.setBrightness(Float($0)) })
    }

    // MARK: Save / Share

    private func save() {
        Task {
            guard let baked = await exportImage(),
                  let png = ImageIO.png(from: baked) else { return }
            let shot = PixelShot(styleID: model.style.id, styleName: model.style.name, pngData: png)
            modelContext.insert(shot)
            ImageIO.saveToPhotos(baked)
            didSave = true
        }
    }

    private func share() {
        Task {
            guard let baked = await exportImage() else { return }
            #if canImport(UIKit)
            shareImage = ShareImage(image: UIImage(cgImage: baked))
            #endif
        }
    }

    /// Bake the export image, stamping the watermark in for free users.
    private func exportImage() async -> CGImage? {
        guard let baked = await model.bakedForExport() else { return nil }
        #if canImport(UIKit)
        return store.isPro ? baked : Watermark.stamp(baked)
        #else
        return baked
        #endif
    }
}
