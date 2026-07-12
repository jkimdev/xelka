//
//  PaywallView.swift
//  xelka
//
//  The single upgrade screen. Presented as a sheet whenever a free user reaches
//  a Pro-gated feature (a locked style, video mode, or the crown button). Reads
//  its price straight from StoreKit via `ProStore`.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store

    /// One line item in the benefits list.
    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let benefits = [
        Benefit(icon: "sparkles", title: "No watermark",
                detail: "Save and share clean, full-quality art."),
        Benefit(icon: "swatchpalette", title: "Every style",
                detail: "Unlock all 11 palettes — CRT, 1-bit, C64 and more."),
        Benefit(icon: "video", title: "Video & GIF",
                detail: "Record pixel-art clips and export animated GIFs."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    benefitList
                }
                .padding(24)
            }
            footer
        }
        .background(Color.black.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .task { await store.refresh() }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
                .padding(.top, 24)
            Text("xelka Pro")
                .font(.largeTitle.bold())
            Text("A one-time unlock. Yours forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 18) {
            ForEach(benefits) { benefit in
                HStack(spacing: 16) {
                    Image(systemName: benefit.icon)
                        .font(.title2)
                        .frame(width: 34)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title).font(.headline)
                        Text(benefit.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Footer (purchase / restore)

    private var footer: some View {
        VStack(spacing: 12) {
            if store.isPro {
                Label("You're all set — enjoy Pro!", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, 8)
            } else {
                purchaseButton
                Button("Restore Purchase") {
                    Task { await store.restore(); if store.isPro { dismiss() } }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .disabled(store.isWorking)
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("One-time purchase • No subscription")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var purchaseButton: some View {
        Button {
            Task { if await store.purchase() { dismiss() } }
        } label: {
            Group {
                if store.isWorking {
                    ProgressView().tint(.black)
                } else {
                    Text(buyTitle).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.yellow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.black)
        }
        .disabled(store.isWorking)
    }

    /// "Unlock Pro — $4.99" once the price loads, else a plain fallback.
    private var buyTitle: String {
        if let price = store.product?.displayPrice {
            return "Unlock Pro — \(price)"
        }
        return "Unlock Pro"
    }
}
