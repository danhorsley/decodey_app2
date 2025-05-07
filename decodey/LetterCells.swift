import SwiftUI

struct EncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let action: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    // Use design systems
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    private let design = DesignSystem.shared
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Container
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? colors.accent : Color.clear, lineWidth: 2)
                    )
                
                // Letter - centered in the cell
                Text(String(letter))
                    .font(fonts.encryptedLetterCell())
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Frequency counter in bottom right
                if frequency > 0 && !isGuessed {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(frequency)")
                                .font(fonts.frequencyIndicator())
                                .foregroundColor(textColor.opacity(0.7))
                                .padding(4)
                        }
                    }
                }
            }
            .frame(minWidth: 40, minHeight: 40)
            .accessibilityLabel("Letter \(letter), frequency \(frequency)")
            .accessibilityHint(getAccessibilityHint())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
    }
    
    // Background color based on state and color scheme
    private var backgroundColor: Color {
        if isSelected {
            return colors.selectedBackground(for: colorScheme, isEncrypted: true)
        } else if isGuessed {
            return colors.guessedBackground(for: colorScheme)
        } else {
            return colors.primaryBackground(for: colorScheme)
        }
    }
    
    // Text color based on state and color scheme
    private var textColor: Color {
        if isSelected {
            return colors.selectedText(for: colorScheme)
        } else if isGuessed {
            return colors.guessedText(for: colorScheme)
        } else {
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
    
    // Use design systems
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    private let design = DesignSystem.shared
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Container
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Letter - centered in the cell
                Text(String(letter))
                    .font(fonts.guessLetterCell())
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
