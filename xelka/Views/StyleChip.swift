//
//  StyleChip.swift
//  xelka
//
//  A selectable pill for a pixel-art style: name over a strip of its palette
//  swatches. Used in the camera bar and the result screen.
//

import SwiftUI

struct StyleChip: View {
    let style: PixelArtStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                swatches
                Text(style.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.5) : Color.secondary.opacity(0.2),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var swatches: some View {
        HStack(spacing: 0) {
            ForEach(Array(sampled.enumerated()), id: \.offset) { _, c in
                Rectangle().fill(Color(c))
            }
        }
        .frame(width: 56, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    /// Show up to 6 evenly-spaced swatches so 16-color strips stay legible.
    private var sampled: [RGBColor] {
        let colors = style.previewColors
        guard colors.count > 6 else { return colors }
        return (0..<6).map { colors[$0 * colors.count / 6] }
    }
}
