import SwiftUI

struct EncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let action: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    // Use color system
    private let colors = ColorSystem.shared
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // Container
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? colors.accent : Color.clear, lineWidth: 2)
                    )
                    .frame(minWidth: 40, minHeight: 40)
                
                // Letter
                Text(String(letter))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
                
                // Frequency counter in bottom right
                if frequency > 0 && !isGuessed {
                    Text("\(frequency)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(textColor.opacity(0.7))
                        .offset(x: -4, y: -4)
                }
            }
            .accessibilityLabel("Letter \(letter), frequency \(frequency)")
            .accessibilityHint(getAccessibilityHint())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
    }
    
    // Background color based on state and color scheme
    private var backgroundColor: Color {
        if isSelected {
            // Selected state - use the selected background color
            return colors.selectedBackground(for: colorScheme, isEncrypted: true)
        } else if isGuessed {
            // Guessed state
            return colors.guessedBackground(for: colorScheme)
        } else {
            // Normal state - match body background
            return colors.primaryBackground(for: colorScheme)
        }
    }
    
    // Text color based on state and color scheme
    private var textColor: Color {
        if isSelected {
            // Selected state - invert colors
            return colors.selectedText(for: colorScheme)
        } else if isGuessed {
            // Guessed state
            return colors.guessedText(for: colorScheme)
        } else {
            // Normal state - use specified colors
            return colors.encryptedText(for: colorScheme)
        }
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
}

struct GuessLetterCell: View {
    let letter: Character
    let isUsed: Bool
    let action: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    // Use color system
    private let colors = ColorSystem.shared
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    Text(String(letter))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minWidth: 36, minHeight: 36)
                .accessibilityLabel("Letter \(letter)")
                .accessibilityHint(isUsed ? "Already used" : "Tap to guess")
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUsed)
    }
    
    // Background color
    private var backgroundColor: Color {
        if isUsed {
            return colors.guessedBackground(for: colorScheme)
        } else {
            return colors.primaryBackground(for: colorScheme)
        }
    }
    
    // Text color
    private var textColor: Color {
        if isUsed {
            return colors.guessedText(for: colorScheme)
        } else {
            return colors.guessText(for: colorScheme)
        }
    }
}
