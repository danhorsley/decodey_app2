import SwiftUI

struct GameGridsView: View {
    @Binding var game: Game
    @Binding var showWinMessage: Bool
    @Binding var showLoseMessage: Bool
    
    let showTextHelpers: Bool
    
    @State private var isHintInProgress = false
    
    // Use environment instead of custom styles
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            // Detect orientation using GeometryReader
            let isLandscape = geometry.size.width > geometry.size.height
            
            if isLandscape || horizontalSizeClass == .regular {
                // Landscape or iPad layout
                HStack(alignment: .center) {
                    encryptedGrid
                    
                    Spacer()
                    
                    hintButton
                    
                    Spacer()
                    
                    guessGrid
                }
                .padding(.horizontal)
            } else {
                // Portrait layout for phones
                VStack(spacing: 24) {
                    encryptedGrid
                    
                    hintButton
                        .padding(.vertical, 8)
                    
                    guessGrid
                }
            }
        }
    }
    
    // Encrypted grid
    private var encryptedGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTextHelpers {
                Text("Select a letter to decode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Create grid
            LazyVGrid(columns: createGridColumns(), spacing: 8) {
                ForEach(game.uniqueEncryptedLetters(), id: \.self) { letter in
                    EncryptedLetterCell(
                        letter: letter,
                        isSelected: game.selectedLetter == letter,
                        isGuessed: game.correctlyGuessed().contains(letter),
                        frequency: game.letterFrequency[letter] ?? 0,
                        action: {
                            withAnimation {
                                game.selectLetter(letter)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // Guess grid
    private var guessGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTextHelpers {
                Text("Guess with:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Get unique letters from the solution
            let uniqueLetters = Array(Set(game.solution.filter { $0.isLetter })).sorted()
            
            // Create grid
            LazyVGrid(columns: createGridColumns(), spacing: 8) {
                ForEach(uniqueLetters, id: \.self) { letter in
                    GuessLetterCell(
                        letter: letter,
                        isUsed: game.guessedMappings.values.contains(letter),
                        action: {
                            if game.selectedLetter != nil {
                                withAnimation {
                                    let _ = game.makeGuess(letter)
                                    
                                    // Check game status
                                    if game.hasWon {
                                        showWinMessage = true
                                    } else if game.hasLost {
                                        showLoseMessage = true
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    // Helper to create adaptive grid columns
    private func createGridColumns() -> [GridItem] {
        #if os(iOS) || os(tvOS)
        let columnCount = horizontalSizeClass == .regular ? 8 : 5
        #else
        let columnCount = 5  // For macOS, always use wider grid
        #endif
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }
    
    // Hint button
    private var hintButton: some View {
        HintButtonView(
            remainingHints: game.maxMistakes - game.mistakes,
            isLoading: isHintInProgress,
            isDarkMode: colorScheme == .dark,
            onHintRequested: {
                // Only perform action if not already in progress
                guard !isHintInProgress else { return }
                
                // Show loading state
                isHintInProgress = true
                
                // Process hint with slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let _ = game.getHint()
                    
                    // Reset loading state
                    isHintInProgress = false
                    
                    // Check game status after hint
                    if game.hasWon {
                        showWinMessage = true
                    } else if game.hasLost {
                        showLoseMessage = true
                    }
                }
            }
        )
    }
}
//
//  GameGridsView.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

