import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool
    let onHintRequested: () -> Void
    
    // Use environment values
    @Environment(\.colorScheme) var colorScheme
    
    // Use design systems
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    // Determine the status color based on remaining hints
    private var statusColor: Color {
        if remainingHints <= 1 {
            return colors.hintButtonDanger(for: colorScheme)
        } else if remainingHints <= 3 {
            return colors.hintButtonWarning(for: colorScheme)
        } else {
            return colors.hintButtonSafe(for: colorScheme)
        }
    }
    
    var body: some View {
        Button(action: onHintRequested) {
            VStack(spacing: 4) {
                // Show spinner when hint is loading
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                        .frame(height: 30)
                        .padding(.vertical, 4)
                } else {
                    // Hint text with monospaced font
                    Text("\(remainingHints)")
                        .font(fonts.hintText())
                        .foregroundColor(statusColor)
                        .frame(height: 30)
                }
                
                // Label underneath
                Text("HINT TOKENS")
                    .font(fonts.hintLabel())
                    .foregroundColor(colors.secondaryText(for: colorScheme))
            }
            .frame(width: design.hintButtonWidth, height: design.hintButtonHeight)
            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(statusColor, lineWidth: 2)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || remainingHints <= 0)
        .accessibilityLabel("Hint Button")
        .accessibilityHint("You have \(remainingHints) hint tokens remaining")
    }
}
