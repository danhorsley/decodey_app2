import SwiftUI
import Metal
import MetalKit

struct GlitchRevealEffect: View {
    let text: String
    let active: Bool
    
    @State private var glitchIntensity: CGFloat = 1.0
    @State private var revealProgress: CGFloat = 0.0
    @State private var glitchCharacters: [String] = []
    @State private var displayText: String = ""
    
    // Characters to use for glitch effect
    private let glitchChars = ["$", "#", "%", "&", "+", "*", "?", "!", "@", "Ω", "∑", "∆", "Φ", "Ψ"]
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .onAppear {
                if active {
                    startGlitchEffect()
                } else {
                    displayText = text
                }
            }
            .onChange(of: active) { newValue in
                if newValue {
                    startGlitchEffect()
                } else {
                    displayText = text
                }
            }
    }
    
    private func startGlitchEffect() {
        // Initialize with full glitch
        displayText = String(repeating: "█", count: text.count)
        
        // Start with all characters as blocks
        var intermediate = Array(repeating: "█", count: text.count)
        
        // Create a timer to progressively reveal characters
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Randomly replace some blocks with glitch chars
            for i in 0..<intermediate.count {
                if intermediate[i] == "█" {
                    if Bool.random() && text[text.index(text.startIndex, offsetBy: i)] != " " {
                        intermediate[i] = glitchChars.randomElement() ?? "#"
                    }
                }
            }
            
            // Progressively reveal actual characters
            if revealProgress < 1.0 {
                // Calculate how many characters to reveal
                let charsToReveal = Int(Double(text.count) * min(revealProgress + 0.1, 1.0)) - Int(Double(text.count) * revealProgress)
                
                // Increment progress
                revealProgress += 0.1
                
                // Get indices of still-concealed characters
                var concealedIndices = [Int]()
                for i in 0..<intermediate.count {
                    let actualChar = text[text.index(text.startIndex, offsetBy: i)]
                    let displayChar = intermediate[i]
                    if displayChar == "█" || glitchChars.contains(String(displayChar)) {
                        concealedIndices.append(i)
                    }
                }
                
                // Shuffle and take the appropriate number to reveal
                concealedIndices.shuffle()
                let toReveal = min(charsToReveal, concealedIndices.count)
                
                for i in 0..<toReveal {
                    if i < concealedIndices.count {
                        let index = concealedIndices[i]
                        let actualChar = String(text[text.index(text.startIndex, offsetBy: index)])
                        intermediate[index] = actualChar
                    }
                }
            }
            
            // Update display text
            displayText = intermediate.joined()
            
            // Stop timer when fully revealed
            if revealProgress >= 1.0 && !intermediate.contains("█") && !intermediate.contains(where: { glitchChars.contains($0) }) {
                timer.invalidate()
                displayText = text
            }
        }
    }
}

// Extension to get character at string index more easily
extension String {
    subscript(i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}

// 1. BASIC PREVIEW PROVIDER

// Add this code at the bottom of your GlitchRevealEffect.swift file:

#if DEBUG
struct GlitchRevealEffect_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview with effect active
            GlitchRevealEffect(
                text: "HELLO WORLD",
                active: true
            )
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            
            // Preview with effect inactive
            GlitchRevealEffect(
                text: "INACTIVE EFFECT",
                active: false
            )
            .padding()
            .foregroundColor(.primary)
        }
        .padding()
    }
}
#endif

// 2. PREVIEW PROVIDER FOR THE TEST VIEW

// Add this at the bottom of your GlitchRevealEffectTestView.swift file:

#if DEBUG
struct GlitchRevealEffectTestView_Previews: PreviewProvider {
    static var previews: some View {
        GlitchRevealEffectTestView()
    }
}
#endif

// 3. PREVIEW FOR WIN OVERLAY

// Add this to the bottom of your WinOverlayView.swift file:

#if DEBUG
struct WinOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            WinOverlayView(
                solution: "THE QUICK BROWN FOX",
                mistakes: 2,
                maxMistakes: 5,
                timeTaken: 120,
                score: 350,
                isDarkMode: true,
                onPlayAgain: {}
            )
        }
    }
}
#endif

// 4. ADVANCED PREVIEW WITH MULTIPLE VARIANTS

// This shows how to create multiple previews for different conditions:

#if DEBUG
struct MultipleVariantsExample_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            WinOverlayView(
                solution: "LIGHT MODE EXAMPLE",
                mistakes: 1,
                maxMistakes: 5,
                timeTaken: 60,
                score: 400,
                isDarkMode: false,
                onPlayAgain: {}
            )
            .previewDisplayName("Light Mode")
            .background(Color.white)
            .environment(\.colorScheme, .light)
            
            // Dark mode preview
            WinOverlayView(
                solution: "DARK MODE EXAMPLE",
                mistakes: 3,
                maxMistakes: 5,
                timeTaken: 180,
                score: 250,
                isDarkMode: true,
                onPlayAgain: {}
            )
            .previewDisplayName("Dark Mode")
            .background(Color.black)
            .environment(\.colorScheme, .dark)
            
            // iPhone SE (smaller screen)
            WinOverlayView(
                solution: "IPHONE SE SIZE",
                mistakes: 2,
                maxMistakes: 5,
                timeTaken: 90,
                score: 325,
                isDarkMode: true,
                onPlayAgain: {}
            )
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE")
            .background(Color.black)
            
            // iPad
            WinOverlayView(
                solution: "IPAD SIZE",
                mistakes: 2,
                maxMistakes: 5,
                timeTaken: 90,
                score: 325,
                isDarkMode: true,
                onPlayAgain: {}
            )
            .previewDevice("iPad (10th generation)")
            .previewDisplayName("iPad")
            .background(Color.black)
        }
    }
}
#endif
