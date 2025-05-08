import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Simple menu controller
struct MainMenuView: View {
    @StateObject private var settings = UserSettings()
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var isGameActive = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Game view
                if isGameActive {
                    ContentView()
                        .environmentObject(settings)
                        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
                }
                
                // Settings sheet
                if showSettings {
                    SettingsView(settings: settings, isPresented: $showSettings)
                        .transition(.move(edge: .bottom))
                        .environmentObject(settings)
                        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
                }
                
                // About sheet
                if showAbout {
                    AboutView(isPresented: $showAbout)
                        .transition(.move(edge: .bottom))
                        .environmentObject(settings)
                        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
                }
            }
            .navigationTitle("decodey")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement(.leading)) {
                    Button(action: { isGameActive.toggle() }) {
                        Label("Menu", systemImage: isGameActive ? "line.horizontal.3" : "xmark")
                    }
                }
                
                ToolbarItem(placement: toolbarItemPlacement(.trailing)) {
                    HStack(spacing: 16) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        
                        Button(action: { showAbout = true }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}

// Simplified Settings View
struct SettingsView: View {
    @ObservedObject var settings: UserSettings
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
            .padding()
            
            // Settings content
            Form {
                Section(header: Text("Display")) {
                    Toggle("Dark Mode", isOn: $settings.isDarkMode)
                        .onChange(of: settings.isDarkMode) { _ in
                            // Force view refresh if needed
                        }
                    
                    Toggle("Show Text Helpers", isOn: $settings.showTextHelpers)
                        .onChange(of: settings.showTextHelpers) { _ in
                            // Force view refresh if needed
                        }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(UIColor.systemBackground))
        #elseif os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(colorScheme == .dark ? Color.black : Color.white)
        #endif
        .cornerRadius(16)
        .padding()
    }
}

// Simplified About View
struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("About decodey")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
            .padding()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A cryptogram puzzle game where you decrypt famous quotes letter by letter.")
                        .padding(.horizontal)
                    
                    GroupBox(label: Label("How to Play", systemImage: "questionmark.circle")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Select a letter from the left grid")
                            Text("2. Guess the original letter")
                            Text("3. Solve before running out of mistakes!")
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color(NSColor.windowBackgroundColor))
        #endif
        .cornerRadius(16)
        .padding()
    }
}

private func toolbarItemPlacement(_ placement: ToolbarPlacement) -> ToolbarItemPlacement {
    #if os(iOS)
    switch placement {
    case .leading:
        return .navigationBarLeading
    case .trailing:
        return .navigationBarTrailing
    default:
        return .navigationBarTrailing
    }
    #else
    switch placement {
    case .leading:
        return .automatic
    case .trailing:
        return .automatic
    default:
        return .automatic
    }
    #endif
}

// Define an enum for our cross-platform placement
enum ToolbarPlacement {
    case leading
    case trailing
    case automatic
}
//
//  MainMenuView.swift
//  decodey
//
//  Created by Daniel Horsley on 08/05/2025.
//

