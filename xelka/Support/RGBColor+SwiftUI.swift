//
//  RGBColor+SwiftUI.swift
//  xelka
//
//  Let engine colors render directly in SwiftUI (palette chips, backgrounds).
//

import SwiftUI

extension Color {
    init(_ c: RGBColor) {
        self.init(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b))
    }
}
