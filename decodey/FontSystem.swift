import SwiftUI

/// FontSystem provides consistent typography across the application
struct FontSystem {
    static let shared = FontSystem()
    
    // MARK: - Font Family
    
    // The primary font for the application (Courier New)
    private func courierNew(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Courier New", size: size).weight(weight)
    }
    
    // Fallback to system monospaced if Courier New isn't available
    private func monospaced(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
    
    // MARK: - Text Styles
    
    // Display and title styles
    func largeTitle(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 34, weight: weight)
    }
    
    func title1(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 28, weight: weight)
    }
    
    func title2(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 22, weight: weight)
    }
    
    func title3(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 20, weight: weight)
    }
    
    // Body text styles
    func body(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 16, weight: weight)
    }
    
    func callout(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 14, weight: weight)
    }
    
    func footnote(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 12, weight: weight)
    }
    
    func caption(bold: Bool = false) -> Font {
        let weight: Font.Weight = bold ? .bold : .regular
        return courierNew(size: 10, weight: weight)
    }
    
    // MARK: - Game-Specific Fonts
    
    // Encrypted text display
    func encryptedDisplay(size: CGFloat? = nil) -> Font {
        courierNew(size: size ?? 18, weight: .regular)
    }
    
    // Solution text display
    func solutionDisplay(size: CGFloat? = nil) -> Font {
        courierNew(size: size ?? 18, weight: .bold)
    }
    
    // Letter cell text
    func letterCell(size: CGFloat? = nil) -> Font {
        courierNew(size: size ?? 22, weight: .bold)
    }
    
    // Frequency counter
    func frequencyCounter() -> Font {
        courierNew(size: 10, weight: .bold)
    }
    
    // Hint button text
    func hintText() -> Font {
        courierNew(size: 24, weight: .bold)
    }
    
    func hintLabel() -> Font {
        courierNew(size: 10, weight: .medium)
    }
    
    // Score display
    func scoreLabel() -> Font {
        courierNew(size: 12, weight: .bold)
    }
    
    func scoreValue() -> Font {
        courierNew(size: 40, weight: .bold)
    }
    
    // MARK: - Responsive Fonts
    
    // Helper method to get font size based on screen category
    func responsiveSize(base: CGFloat, for screenCategory: DesignSystem.ScreenSizeCategory) -> CGFloat {
        switch screenCategory {
        case .small:
            return base - 2
        case .medium:
            return base
        case .large:
            return base + 2
        default:
            return base + 2
        }
    }
    
    // Get responsive letter cell font
    func responsiveLetterCell(for screenCategory: DesignSystem.ScreenSizeCategory) -> Font {
        let size = responsiveSize(base: 22, for: screenCategory)
        return letterCell(size: size)
    }
    
    // Get responsive display font
    func responsiveDisplay(for screenCategory: DesignSystem.ScreenSizeCategory, isSolution: Bool = false) -> Font {
        let size = responsiveSize(base: 18, for: screenCategory)
        return isSolution ? solutionDisplay(size: size) : encryptedDisplay(size: size)
    }
}
//
//  FontSystem.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

