import SwiftUI

/// ColorSystem provides consistent color theming across the application
struct ColorSystem {
    static let shared = ColorSystem()
    
    // MARK: - Brand Colors
    
    /// Primary app accent color
    var accent: Color {
        Color.blue
    }
    
    // MARK: - Semantic Colors
    
    var success: Color {
        Color.green
    }
    
    var warning: Color {
        Color.orange
    }
    
    var error: Color {
        Color.red
    }
    
    // MARK: - Text Colors
    
    func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    // MARK: - Background Colors
    
    func primaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
    }
    
    // MARK: - Game-Specific Colors
    
    // Encrypted Grid
    func encryptedText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "4cc9f0") : Color.black
    }
    
    // Guess Grid
    func guessText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00ed99") : Color(hex: "0042aa")
    }
    
    // Selected state
    func selectedBackground(for colorScheme: ColorScheme, isEncrypted: Bool) -> Color {
        if isEncrypted {
            return colorScheme == .dark ? Color(hex: "4cc9f0") : Color.black
        } else {
            return colorScheme == .dark ? Color(hex: "00ed99") : Color(hex: "0042aa")
        }
    }
    
    func selectedText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    // Guessed state
    func guessedText(for colorScheme: ColorScheme) -> Color {
        Color.gray
    }
    
    func guessedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    // MARK: - Hint Button Colors
    
    func hintButtonSafe(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "4cc9f0") : Color.blue
    }
    
    func hintButtonWarning(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF9E64") : Color.orange
    }
    
    func hintButtonDanger(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF5277") : Color.red
    }
    
    // MARK: - Overlay Colors
    
    func overlayBackground(opacity: Double = 0.75) -> Color {
        Color.black.opacity(opacity)
    }
    
    func winColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00ed99") : Color.green
    }
    
    func loseColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF5277") : Color.red
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
//
//  ColorSystem.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

