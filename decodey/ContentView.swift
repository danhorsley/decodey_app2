import SwiftUI

struct ContentView: View {
    @State private var game = Game()
    @State private var showWinMessage = false
    @State private var showLoseMessage = false
    
    var body: some View {
        ZStack {
            // Background using system colors
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Game title
                Text("Decodey")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                // Display area
                displayTextArea
                
                // Game grid with letters
                GameGridView(
                    game: $game,
                    showWinMessage: $showWinMessage,
                    showLoseMessage: $showLoseMessage
                )
                
                Spacer()
            }
            .padding()
            
            // Win message overlay
            if showWinMessage {
                winMessageOverlay
            }
            
            // Lose message overlay
            if showLoseMessage {
                loseMessageOverlay
            }
        }
        .onAppear {
            // Start a new game when the app appears
            resetGame()
        }
    }
    
    // Display area for the encrypted and solution text
    private var displayTextArea: some View {
        VStack(spacing: 16) {
            // Encrypted text
            VStack(alignment: .leading) {
                Text("Encrypted:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(game.encrypted)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Solution with blocks
            VStack(alignment: .leading) {
                Text("Your solution:")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(game.currentDisplay)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // Game grid view
    private var GameGridView: some View {
        GeometryReader { geometry in
            // Detect orientation using GeometryReader
            let isLandscape = geometry.size.width > geometry.size.height
            
            if isLandscape {
                // Landscape layout
                HStack(alignment: .center, spacing: 20) {
                    // Encrypted letters grid
                    encryptedGrid
                    
                    // Hint button
                    hintButton
                    
                    // Guess letters grid
                    guessGrid
                }
                .padding(.horizontal)
            } else {
                // Portrait layout
                VStack(spacing: 20) {
                    // Encrypted letters grid
                    encryptedGrid
                    
                    // Hint button
                    hintButton
                    
                    // Guess letters grid
                    guessGrid
                }
            }
        }
        .frame(height: 300) // Fixed height for now
    }
    
    // Encrypted letters grid
    private var encryptedGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a letter to decode:")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
    
    // Guess letters grid
    private var guessGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guess with:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Create grid with all letters A-Z
            let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            
            LazyVGrid(columns: createGridColumns(), spacing: 8) {
                ForEach(Array(alphabet), id: \.self) { letter in
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
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    }
    
    // Hint button
    private var hintButton: some View {
        Button(action: {
            // Process hint
            let _ = game.getHint()
            
            // Check game status after hint
            if game.hasWon {
                showWinMessage = true
            } else if game.hasLost {
                showLoseMessage = true
            }
        }) {
            VStack(spacing: 4) {
                Text("\(game.maxMistakes - game.mistakes)")
                    .font(.title.bold())
                    .foregroundColor(getHintColor())
                
                Text("HINT TOKENS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 60)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(getHintColor(), lineWidth: 2)
            )
        }
        .disabled(game.maxMistakes - game.mistakes <= 0)
    }
    
    // Helper for hint button color
    private func getHintColor() -> Color {
        let remaining = game.maxMistakes - game.mistakes
        if remaining <= 1 {
            return .red
        } else if remaining <= 3 {
            return .orange
        } else {
            return .blue
        }
    }
    
    // Win message overlay
    private var winMessageOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                Text("You Win!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.green)
                
                Text(game.solution)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                
                // Score display
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text("\(game.calculateScore())")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(game.mistakes)/\(game.maxMistakes)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(Int(game.lastUpdateTime.timeIntervalSince(game.startTime))))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical)
                
                Button(action: resetGame) {
                    Text("Play Again")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(32)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // Lose message overlay
    private var loseMessageOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                Text("Game Over")
                    .font(.largeTitle.bold())
                    .foregroundColor(.red)
                
                Text("The solution was:")
                    .foregroundColor(.white)
                
                Text(game.solution)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(game.mistakes)/\(game.maxMistakes)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(Int(game.lastUpdateTime.timeIntervalSince(game.startTime))))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical)
                
                Button(action: resetGame) {
                    Text("Try Again")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(32)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // Reset game function
    private func resetGame() {
        // Create a new game
        game = Game()
        showWinMessage = false
        showLoseMessage = false
    }
    
    // Format time in seconds to MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
