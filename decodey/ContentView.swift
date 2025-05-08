import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: UserSettings
    @State private var game = Game()
    @State private var showWinMessage = false
    @State private var showLoseMessage = false
    
    // Use DesignSystem for consistent sizing
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background color that matches the letter cells in light mode
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: design.displayAreaPadding) {
                // Game title
                Text("decodey")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                // Display area
                displayTextArea
                
                // Game grid with letters
                GameGridsView(
                    game: $game,
                    showWinMessage: $showWinMessage,
                    showLoseMessage: $showLoseMessage,
                    showTextHelpers: settings.showTextHelpers
                )
                
                Spacer()
            }
            .padding(design.displayAreaPadding)
            
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
            resetGame()
        }
    }
    
    // Display area for the encrypted and solution text
    private var displayTextArea: some View {
        VStack(spacing: 16) {
            // Encrypted text
            VStack(alignment: .leading) {
                if settings.showTextHelpers {
                    Text("Encrypted:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(game.encrypted)
                    .font(.system(size: design.displayFontSize, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Solution with blocks
            VStack(alignment: .leading) {
                if settings.showTextHelpers {
                    Text("Your solution:")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Text(game.currentDisplay)
                    .font(.system(size: design.displayFontSize, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // Win message overlay
    private var winMessageOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            WinOverlayView(
                solution: game.solution,
                mistakes: game.mistakes,
                maxMistakes: game.maxMistakes,
                timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
                score: game.calculateScore(),
                isDarkMode: settings.isDarkMode,
                onPlayAgain: resetGame
            )
            .frame(width: design.overlayWidth)
            .cornerRadius(design.overlayCornerRadius)
        }
    }
    
    // Lose message overlay
    private var loseMessageOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            LoseOverlayView(
                solution: game.solution,
                mistakes: game.mistakes,
                maxMistakes: game.maxMistakes,
                timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
                isDarkMode: settings.isDarkMode,
                onTryAgain: resetGame
            )
            .frame(width: design.overlayWidth)
            .cornerRadius(design.overlayCornerRadius)
        }
    }
    
    // Reset game function
    private func resetGame() {
        // Create a new game
        game = Game()
        showWinMessage = false
        showLoseMessage = false
    }
}
