import SwiftUI

// MARK: - Holographic Text Reveal Effect - Fixed Cross-Platform Version
struct HolographicRevealEffect: View {
    let text: String
    let active: Bool
    
    // Configuration
    private let scanLineCount = 3
    private let scanLineHeight: CGFloat = 1.5
    private let noiseIntensity: CGFloat = 0.04
    private let glitchFrequency = 0.15
    
    // Animation states
    @State private var revealProgress: CGFloat = 0.0
    @State private var scanLinePositions: [CGFloat] = []
    @State private var glitchOffset: CGFloat = 0.0
    @State private var characterGlitches: [Bool] = []
    @State private var timer: Timer? = nil
    @State private var charOpacities: [Double] = []
    @State private var charOffsets: [CGSize] = []
    @State private var displayText = ""
    
    // For shimmer effect
    @State private var shimmerProgress: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with grid pattern
                gridBackground
                    .opacity(active ? 0.3 : 0)
                
                // Character-by-character text with effects
                Text(displayText)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(HolographicModifier(progress: shimmerProgress))
                
                // Scan lines
                ForEach(0..<scanLinePositions.count, id: \.self) { index in
                    scanLine(width: geometry.size.width, at: scanLinePositions[index])
                }
                
                // Noise overlay
                Color.white
                    .opacity(active ? noiseIntensity : 0)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
            .onAppear {
                if active {
                    startHolographicEffect()
                }
            }
            // Use the new onChange syntax compatible with both iOS 17+ and macOS 14+
            .onChange(of: active) { _, newValue in
                if newValue {
                    startHolographicEffect()
                } else {
                    resetEffect()
                }
            }
        }
    }
    
    // Grid pattern background
    private var gridBackground: some View {
        Canvas { context, size in
            // Draw horizontal grid lines
            for y in stride(from: 0, to: size.height, by: 10) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: 0.5)
            }
            
            // Draw vertical grid lines
            for x in stride(from: 0, to: size.width, by: 10) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }
    
    // Scan line view
    private func scanLine(width: CGFloat, at yPosition: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .cyan.opacity(0.7), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: scanLineHeight)
            .offset(y: yPosition)
            .opacity(active ? 0.7 : 0)
            .blendMode(.screen)
    }
    
    // Start the holographic effect
    private func startHolographicEffect() {
        // Reset
        resetEffect()
        
        // Initialize arrays for each character
        let characters = Array(text)
        charOpacities = Array(repeating: 0.0, count: characters.count)
        charOffsets = Array(repeating: .zero, count: characters.count)
        characterGlitches = Array(repeating: false, count: characters.count)
        displayText = String(repeating: " ", count: characters.count)
        
        // Initialize scan lines
        scanLinePositions = []
        for _ in 0..<scanLineCount {
            scanLinePositions.append(CGFloat.random(in: -50...50))
        }
        
        // Start shimmer animation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            shimmerProgress = 1.0
        }
        
        // Timer for animation updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Update scan line positions
            for i in 0..<scanLinePositions.count {
                scanLinePositions[i] = (scanLinePositions[i] + 2).truncatingRemainder(dividingBy: 100) - 50
            }
            
            // Gradually reveal characters
            if revealProgress < 1.0 {
                revealProgress += 0.01
                
                // Update character states based on reveal progress
                for i in 0..<characters.count {
                    let shouldReveal = Double(i) / Double(characters.count) <= Double(revealProgress)
                    
                    if shouldReveal && charOpacities[i] < 1.0 {
                        // Randomly decide to reveal this character
                        if Bool.random() {
                            charOpacities[i] = 1.0
                            
                            // Replace placeholder with actual character
                            var displayChars = Array(displayText)
                            displayChars[i] = characters[i]
                            displayText = String(displayChars)
                        }
                    }
                    
                    // Randomly apply glitch effect to unrevealed characters
                    if !shouldReveal && Bool.random(withProbability: glitchFrequency) {
                        characterGlitches[i] = true
                        
                        // Show random character for glitch effect
                        var displayChars = Array(displayText)
                        displayChars[i] = randomGlitchChar()
                        displayText = String(displayChars)
                        
                        // Reset glitch after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            characterGlitches[i] = false
                            
                            // Restore space if not revealed yet
                            if Double(i) / Double(characters.count) > Double(revealProgress) {
                                var displayChars = Array(displayText)
                                displayChars[i] = " "
                                displayText = String(displayChars)
                            }
                        }
                    }
                }
            } else if displayText != text {
                // Ensure all characters are revealed at the end
                displayText = text
            }
            
            // Apply occasional global glitch
            if Bool.random(withProbability: 0.05) {
                glitchOffset = CGFloat.random(in: -5...5)
                
                // Reset glitch after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    glitchOffset = 0
                }
            }
            
            // Stop timer when complete and stable
            if revealProgress >= 1.0 && displayText == text && !characterGlitches.contains(true) && glitchOffset == 0 {
                // Keep running for scan line and shimmer effects
            }
        }
    }
    
    // Reset the effect
    private func resetEffect() {
        timer?.invalidate()
        timer = nil
        revealProgress = 0.0
        glitchOffset = 0.0
        scanLinePositions = []
        characterGlitches = []
        charOpacities = []
        charOffsets = []
        displayText = ""
        shimmerProgress = 0.0
    }
    
    // Generate a random character for glitch effect
    private func randomGlitchChar() -> Character {
        let glitchChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-=_+[]{}|;:'\",.<>/?\\`~"
        return glitchChars.randomElement() ?? "X"
    }
}

// Holographic modifier for shimmer effect
struct HolographicModifier: ViewModifier {
    let progress: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Diagonal shimmer
                GeometryReader { geometry in
                    Color.white
                        .opacity(0.5)
                        .blendMode(.overlay)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: progress - 0.2),
                                            .init(color: .white.opacity(0.7), location: progress),
                                            .init(color: .clear, location: progress + 0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            )
            .overlay(
                // Horizontal scan line
                GeometryReader { geometry in
                    Color.cyan.opacity(0.4)
                        .blendMode(.screen)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: progress - 0.01),
                                            .init(color: .white, location: progress),
                                            .init(color: .clear, location: progress + 0.01)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                }
            )
    }
}

// Extension to add probability-based random Bool
extension Bool {
    static func random(withProbability probability: Double) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}

// MARK: - Win Overlay Using Holographic Effect
struct HolographicWinOverlayView: View {
    let solution: String
    let mistakes: Int
    let maxMistakes: Int
    let timeTaken: Int
    let score: Int
    let isDarkMode: Bool
    let onPlayAgain: () -> Void
    
    @State private var showRevealEffect = true
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButton = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background blur and overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Win message
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5, x: 0, y: 0)
                
                // Solution with holographic reveal effect
                HolographicRevealEffect(text: solution, active: showRevealEffect)
                    .frame(height: 50)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                // Score display
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.7), radius: 3, x: 0, y: 0)
                }
                .padding()
                .frame(width: 200)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .opacity(showScore ? 1 : 0)
                .scaleEffect(showScore ? 1 : 0.8)
                
                // Game stats
                HStack(spacing: 30) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(mistakes)/\(maxMistakes)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(timeTaken))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical)
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)
                
                // Play again button
                Button(action: {
                    // Reset animations
                    showRevealEffect = false
                    showScore = false
                    showStats = false
                    showButton = false
                    
                    // Small delay before calling onPlayAgain
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onPlayAgain()
                    }
                }) {
                    Text("Play Again")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(BorderlessButtonStyle())
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .onAppear {
                // Staggered animations for each element
                // The reveal effect starts immediately
                
                // Show score after the reveal effect has started
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) {
                        showScore = true
                    }
                }
                
                // Show stats after score
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showStats = true
                    }
                }
                
                // Show button last
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring()) {
                        showButton = true
                    }
                }
            }
        }
    }
    
    // Format time in seconds to MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct HolographicRevealEffect_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Holographic Effect Preview
            HolographicRevealEffect(text: "HOLOGRAPHIC", active: true)
                .frame(height: 100)
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Holographic Effect")
            
            // Win Overlay Preview
            HolographicWinOverlayView(
                solution: "THE QUICK BROWN FOX",
                mistakes: 2,
                maxMistakes: 5,
                timeTaken: 120,
                score: 350,
                isDarkMode: true,
                onPlayAgain: {}
            )
            .previewDisplayName("Holographic Win Overlay")
        }
    }
}
#endif
