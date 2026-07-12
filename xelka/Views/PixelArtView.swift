//
//  PixelArtView.swift
//  xelka
//
//  Renders a small art CGImage with nearest-neighbor scaling so every pixel
//  stays a crisp square no matter how large it's shown.
//

import SwiftUI

struct PixelArtView: View {
    let cgImage: CGImage

    var body: some View {
        Image(decorative: cgImage, scale: 1, orientation: .up)
            .interpolation(.none)
            .antialiased(false)
            .resizable()
            .aspectRatio(CGFloat(cgImage.width) / CGFloat(cgImage.height), contentMode: .fit)
    }
}
