//
//  decodeyApp.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

import SwiftUI

@main
struct decodeyApp: App {
    @State private var showWelcome = true
    
    var body: some Scene {
        WindowGroup {
            if showWelcome {
                WelcomeScreen(onComplete: {
                    withAnimation {
                        showWelcome = false
                    }
                })
            } else {
                MainMenuView()
            }
        }
    }
}

