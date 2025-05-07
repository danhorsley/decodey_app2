import SwiftUI

struct EncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let action: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // Background and content
                Text(String(letter))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .frame(minWidth: 40, minHeight: 40)
                    .background(backgroundForState())
                    .foregroundColor(foregroundForState())
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                
                // Frequency counter in bottom right
                if frequency > 0 && !isGuessed {
                    Text("\(frequency)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(getFrequencyColor())
                        .offset(x: -4, y: -4)
                }
            }
            .accessibilityLabel("Letter \(letter), frequency \(frequency)")
            .accessibilityHint(getAccessibilityHint())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
    }
    
    // Helper function for frequency color
    private func getFrequencyColor() -> Color {
        let baseColor = foregroundForState()
        return baseColor.opacity(0.7)
    }
    
    // Helper function for accessibility hint
    private func getAccessibilityHint() -> String {
        if isGuessed {
            return "Already guessed"
        } else if isSelected {
            return "Currently selected"
        } else {
            return "Tap to select"
        }
    }
    
    // Background color based on state using system colors
    private func backgroundForState() -> Color {
        if isGuessed {
            return colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
        } else if isSelected {
            return Color.accentColor
        } else {
            return colorScheme == .dark ? Color.blue.opacity(0.7) : Color.blue.opacity(0.8)
        }
    }
    
    // Foreground (text) color based on state
    private func foregroundForState() -> Color {
        if isGuessed {
            return Color.gray
        } else if isSelected {
            return colorScheme == .dark ? Color.black : Color.white
        } else {
            return .white
        }
    }
}

struct GuessLetterCell: View {
    let letter: Character
    let isUsed: Bool
    let action: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(String(letter))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .frame(minWidth: 36, minHeight: 36)
                .background(getBackgroundColor())
                .foregroundColor(getForegroundColor())
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .accessibilityLabel("Letter \(letter)")
                .accessibilityHint(isUsed ? "Already used" : "Tap to guess")
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUsed)
    }
    
    // Helper function for background color
    private func getBackgroundColor() -> Color {
        if isUsed {
            return colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
        } else {
            return colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1)
        }
    }
    
    // Helper function for foreground color
    private func getForegroundColor() -> Color {
        if isUsed {
            return Color.gray
        } else {
            return colorScheme == .dark ? Color.white : Color.black
        }
    }
}
//
//  LetterCells.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

