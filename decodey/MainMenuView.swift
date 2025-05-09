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
    @State private var showWelcome = true
    
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
            // Cross-platform navigation title
            #if os(iOS)
            .navigationTitle("decodey")
            .navigationBarTitleDisplayMode(.inline)
            #else
            .navigationTitle("decodey")
            #endif
            
            // Cross-platform toolbar
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isGameActive.toggle() }) {
                        Label("Menu", systemImage: isGameActive ? "line.horizontal.3" : "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        
                        Button(action: { showAbout = true }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                #else
                // macOS toolbar items
                ToolbarItem(placement: .automatic) {
                    Button(action: { isGameActive.toggle() }) {
                        Label("Menu", systemImage: isGameActive ? "line.horizontal.3" : "xmark")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 16) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        
                        Button(action: { showAbout = true }) {
                            Image(systemName: "info.circle")
                        }
                    }
                }
                #endif
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
        
        // Welcome screen overlay
        if showWelcome {
            WelcomeScreen(onComplete: {
                withAnimation {
                    showWelcome = false
                }
            })
            .transition(.opacity)
            .zIndex(100)
        }
    }
}

// Simplified Settings View
struct SettingsView: View {
    @ObservedObject var settings: UserSettings
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authState: AuthState
    
    // Local state
    @State private var showingConfirmation = false
    @State private var confirmationMessage = ""
    @State private var confirmationAction: (() -> Void)?
    @State private var showingAbout = false
    
    // Biometric settings
    private let biometricType = BiometricAuthHelper.shared.getBiometricType()
    private let biometricName = BiometricAuthHelper.shared.biometricAuthAvailable().1
    
    var body: some View {
        NavigationView {
            Form {
                // Theme section
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $settings.isDarkMode)
                    
                    Toggle("Show Text Helpers", isOn: $settings.showTextHelpers)
                    
                    Toggle("Larger Text", isOn: $settings.useAccessibilityTextSize)
                }
                
                // Security section (only for authenticated users)
                if authState.isAuthenticated {
                    Section(header: Text("Security")) {
                        // Only show biometric toggle if available on device
                        if biometricType != .none {
                            Toggle(isOn: $settings.useBiometricAuth) {
                                HStack {
                                    Image(systemName: biometricType.iconName)
                                        .foregroundColor(.accentColor)
                                    Text("Use \(biometricName)")
                                }
                            }
                            .onChange(of: settings.useBiometricAuth) { newValue in
                                // Modern onChange syntax for macOS 14+ and iOS 17+
                                if #available(iOS 17.0, macOS 14.0, *) {
                                    // New style already handled by the platform
                                } else {
                                    // Handle older platforms
                                    if newValue && biometricType != .none {
                                        // Attempt to enable biometric auth
                                        let success = authState.enableBiometricAuth()
                                        
                                        if !success {
                                            // Show error and revert setting
                                            confirmationMessage = "Failed to enable biometric authentication. Please try again later."
                                            showingConfirmation = true
                                            settings.useBiometricAuth = false
                                        }
                                    }
                                }
                            }
                            
                            if settings.useBiometricAuth {
                                Text("You can use \(biometricName) to log in quickly even when offline.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            confirmationMessage = "Are you sure you want to log out? You will need to log in again."
                            confirmationAction = { authState.logout() }
                            showingConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                Text("Log Out")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Offline sync section
                    if settings.isOfflineMode {
                        Section(header: Text("Offline Status")) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Offline Mode")
                                    .foregroundColor(.orange)
                            }
                            
                            Text("Some features may be limited until you're back online. Your data will sync automatically when a connection is restored.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                            
                            // Display pending operations count
                            if OfflineSyncService.shared.pendingOperationCount > 0 {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("\(OfflineSyncService.shared.pendingOperationCount) changes pending sync")
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
                
                // About section
                Section(header: Text("About")) {
                    Button(action: {
                        showingAbout = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                            Text("About Decodey")
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(settings.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    // Reset to defaults button
                    Button(action: {
                        confirmationMessage = "Are you sure you want to reset all settings to defaults?"
                        confirmationAction = { settings.resetToDefaults() }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Reset to Defaults")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            // Cross-platform navigation title
            #if os(iOS)
            .navigationTitle("Settings")
            #else
            .navigationTitle("Settings")
            #endif
            
            // Cross-platform toolbar
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                #else
                ToolbarItem {
                    Button("Done") {
                        isPresented = false
                    }
                }
                #endif
            }
            
            // Cross-platform alert
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Confirm"),
                    message: Text(confirmationMessage),
                    primaryButton: .destructive(Text("Continue")) {
                        confirmationAction?()
                    },
                    secondaryButton: .cancel()
                )
            }
            
            // Cross-platform sheet presentation
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}

struct AboutView: View {
    // Optional binding for presenting as a sheet
    var isPresented: Binding<Bool>? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // App logo and title
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("decodey")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                            
                            Text("Crack the code!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Decodey")
                            .font(.headline)
                        
                        Text("Decodey is a word puzzle game where you decrypt famous quotes by solving a substitution cipher. Each letter in the alphabet has been replaced with another letter, and your job is to figure out which is which!")
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // How to play
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Play")
                            .font(.headline)
                        
                        Text("1. Select an encrypted letter from the left grid")
                            .font(.body)
                        
                        Text("2. Choose what letter you think it represents from the right grid")
                            .font(.body)
                        
                        Text("3. Continue until you've decrypted the entire quote")
                            .font(.body)
                        
                        Text("4. If you get stuck, use a hint token - but be careful, you only have a limited number!")
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("Developed by: Daniel Horsley")
                            .font(.body)
                        
                        Text("Design: Freeform LLC")
                            .font(.body)
                        
                        Text("All quotes are attributed where known and are used for educational and entertainment purposes only.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            // Cross-platform navigation title and done button
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let isPresented = isPresented {
                        Button("Done") {
                            isPresented.wrappedValue = false
                        }
                    }
                }
                #else
                ToolbarItem {
                    if let isPresented = isPresented {
                        Button("Done") {
                            isPresented.wrappedValue = false
                        }
                    }
                }
                #endif
            }
            #if os(iOS)
            .navigationBarTitle("About", displayMode: .inline)
            #else
            .navigationTitle("About")
            #endif
        }
    }
}

// For SwiftUI preview
#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: UserSettings(), isPresented: .constant(true))
            .environmentObject(AuthState.shared)
    }
}
#endif
