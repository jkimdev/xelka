//
//  PixelShot.swift
//  xelka
//
//  A saved pixel-art photo. We persist the baked (upscaled, crisp) PNG so the
//  gallery renders instantly without re-running the engine, plus which style
//  produced it.
//

import Foundation
import SwiftData

@Model
final class PixelShot {
    var createdAt: Date
    var styleID: String
    var styleName: String
    /// Baked nearest-neighbor PNG of the finished art.
    @Attribute(.externalStorage) var pngData: Data

    init(createdAt: Date = Date(), styleID: String, styleName: String, pngData: Data) {
        self.createdAt = createdAt
        self.styleID = styleID
        self.styleName = styleName
        self.pngData = pngData
    }
}
