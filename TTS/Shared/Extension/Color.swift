//
//  Color.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//


import SwiftUI

extension Color {
    static let myPrimaryColor = Color(red: 67/255, green: 90/255, blue: 246/255)
    static let secondaryTextBGColor = Color(red: 65/255, green: 51/255, blue: 42/255)
}

extension ShapeStyle where Self == Color {
    static var myPrimaryColor: Color { Color.myPrimaryColor }
}

extension Color {
    init(hex: String, opacity: Double? = 1.0) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hexString.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = opacity ?? 0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = opacity ?? 00
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
