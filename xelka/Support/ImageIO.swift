//
//  ImageIO.swift
//  xelka
//
//  Small bridges between the engine's CGImage output and the things the app
//  needs: SwiftUI images, PNG data for persistence, and the system photo album.
//

#if canImport(UIKit)
import UIKit

enum ImageIO {
    /// PNG-encode a CGImage (used to persist the baked art).
    static func png(from cgImage: CGImage) -> Data? {
        UIImage(cgImage: cgImage).pngData()
    }

    /// Decode persisted PNG back to a CGImage for display.
    static func cgImage(from data: Data) -> CGImage? {
        UIImage(data: data)?.cgImage
    }

    /// Save a finished art image to the user's photo library (add-only).
    static func saveToPhotos(_ cgImage: CGImage) {
        UIImageWriteToSavedPhotosAlbum(UIImage(cgImage: cgImage), nil, nil, nil)
    }
}
#endif
