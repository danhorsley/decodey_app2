import SwiftUI

struct GlitchRevealEffectTestView: View {
    @State private var isActive = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Glitch Effect Test")
                .font(.title)
                .padding()
            
            GlitchRevealEffect(
                text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
                active: isActive
            )
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button(action: {
                // Toggle the effect
                isActive.toggle()
            }) {
                Text(isActive ? "Reset Effect" : "Trigger Effect")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(isActive ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Text("Push the button to test the glitch effect")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

//
//  GlitchRevealEffectTestView.swift
//  decodey
//
//  Created by Daniel Horsley on 08/05/2025.
//

