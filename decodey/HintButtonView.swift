import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool
    let onHintRequested: () -> Void
    
    // Convert remaining hint count to text representation
    private var hintText: String {
        String(remainingHints)
    }
    
    // Determine the status color based on remaining hints
    private var statusColor: Color {
        if remainingHints <= 1 {
            return .red
        } else if remainingHints <= 3 {
            return .orange
        } else {
            return .accentColor
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
                    Text(hintText)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                        .frame(height: 30)
                }
                
                // Label underneath
                Text("HINT TOKENS")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(width: 110, height: 70)
            .background(isDarkMode ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
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
//
//  HintButtonView.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

