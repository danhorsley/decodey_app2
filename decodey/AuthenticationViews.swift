import SwiftUI
import LocalAuthentication
#if os(iOS)
import UIKit
#endif

// MARK: - Utility Extensions for Cross-Platform Support

extension View {
    /// Platform-agnostic navigation title
    @ViewBuilder
    func platformNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            self.navigationTitle(title)
        } else {
            self.navigationBarTitle(title)
        }
        #else
        self.navigationTitle(title)
        #endif
    }
    
    /// Platform-agnostic trailing navigation bar items
    @ViewBuilder
    func platformNavigationBarTrailing<Content: View>(_ content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            self.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    content
                }
            }
        } else {
            self.navigationBarItems(trailing: content)
        }
        #else
        self.toolbar {
            ToolbarItem(placement: .automatic) {
                content
            }
        }
        #endif
    }
    
    /// Platform-agnostic leading navigation bar items
    @ViewBuilder
    func platformNavigationBarLeading<Content: View>(_ content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 14.0, *) {
            self.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    content
                }
            }
        } else {
            self.navigationBarItems(leading: content)
        }
        #else
        self.toolbar {
            ToolbarItem(placement: .automatic) {
                content
            }
        }
        #endif
    }
    
    /// Platform-agnostic onChange handler that works with the new API
    @ViewBuilder
    func platformOnChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

// MARK: - Authentication Coordinator

/// Coordinates the authentication flow and transitions between states
struct AuthCoordinator: View {
    @StateObject private var authState = AuthState.shared
    @State private var showingWelcome = true
    
    var body: some View {
        ZStack {
            // Main content
            if authState.isAuthenticated {
                // User is authenticated - show main app content
                MainMenuView()
                    .environmentObject(authState)
                    .transition(.opacity)
            } else {
                // User is not authenticated - show login/welcome
                if showingWelcome {
                    // Show welcome screen first
                    WelcomeScreen(onComplete: {
                        withAnimation {
                            showingWelcome = false
                        }
                    })
                    .transition(.opacity)
                } else {
                    // Show login screen
                    LoginView()
                        .environmentObject(authState)
                        .transition(.opacity)
                }
            }
            
            // Offline mode banner
            if authState.isAuthenticated && authState.isOfflineMode {
                VStack {
                    // Offline banner at the top
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        
                        Text("Offline Mode")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .zIndex(999)
                    
                    Spacer()
                }
                .edgesIgnoringSafeArea(.top)
            }
        }
        .animation(.easeInOut, value: authState.isAuthenticated)
        .animation(.easeInOut, value: authState.isOfflineMode)
        .onAppear {
            // Check if we need to show welcome screen
            // You might want to check if this is the first launch
            let hasSeenWelcome = UserDefaults.standard.bool(forKey: "has_seen_welcome")
            showingWelcome = !hasSeenWelcome
            
            // If this isn't the first launch, set the flag
            if !hasSeenWelcome {
                UserDefaults.standard.set(true, forKey: "has_seen_welcome")
            }
        }
    }
}

// MARK: - Network Status View

/// A view that displays network status changes
struct NetworkStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showingBanner = false
    
    var body: some View {
        Group {
            if !networkMonitor.isConnected && showingBanner {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        
                        Text(networkMonitor.isConnected ? "Back Online" : "No Internet Connection")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                showingBanner = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(networkMonitor.isConnected ? Color.green : Color.orange)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    Spacer()
                }
                .transition(.move(edge: .top))
                .animation(.spring(), value: networkMonitor.isConnected)
                .animation(.spring(), value: showingBanner)
            }
        }
        .onReceive(NetworkMonitor.shared.$isConnected) { isConnected in
            withAnimation {
                // Only show banner when status changes
                showingBanner = true
                
                // Auto-hide after delay if back online
                if isConnected {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            if networkMonitor.isConnected {
                                showingBanner = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - LoginView

/// The login screen for the app
struct LoginView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.colorScheme) var colorScheme
    
    @State private var identifier = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var showingSignup = false
    @State private var showingPasswordReset = false
    @State private var isOfflineMode = false
    @State private var biometricType = BiometricAuthHelper.shared.getBiometricType()
    @State private var showingBiometricPrompt = false
    
    // Design
    private let colors = ColorSystem.shared
    
    var body: some View {
        ZStack {
            // Background using ColorSystem
            colors.primaryBackground(for: colorScheme)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Logo area
                VStack(spacing: 12) {
                    // App logo
                    Text("decodey")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(colors.accent)
                        .padding(.top, 40)
                    
                    Text("Login to your account")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
                
                // Network status indicator
                if isOfflineMode {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        Text("Offline Mode")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(colors.warning.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Login form
                VStack(spacing: 16) {
                    // Username/Email field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username or Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("", text: $identifier)
                            .disableAutocorrection(true)
                            .padding()
                            .background(colors.secondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colors.border(for: colorScheme), lineWidth: 1)
                            )
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("", text: $password)
                            .padding()
                            .background(colors.secondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colors.border(for: colorScheme), lineWidth: 1)
                            )
                    }
                    
                    // Remember me and forgot password
                    HStack {
                        // Remember me toggle
                        Toggle(isOn: $rememberMe) {
                            Text("Remember me")
                                .font(.subheadline)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: colors.accent))
                        
                        Spacer()
                        
                        // Forgot password button
                        Button(action: {
                            showingPasswordReset = true
                        }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(colors.accent)
                        }
                    }
                    .padding(.top, 4)
                    
                    // Error message
                    if let error = authState.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(colors.error)
                            .padding(.top, 8)
                    }
                    
                    // Login button
                    Button(action: performLogin) {
                        if authState.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(colors.accent)
                                .cornerRadius(8)
                        } else {
                            Text("Log In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(colors.accent)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(authState.isLoading || identifier.isEmpty || password.isEmpty)
                    .padding(.top, 8)
                    
                    // Biometric login button - only show if available and we're offline
                    if biometricType != .none && isOfflineMode {
                        Button(action: performBiometricLogin) {
                            HStack {
                                Image(systemName: biometricType.iconName)
                                    .font(.headline)
                                
                                Text("Login with \(biometricType.description)")
                                    .font(.headline)
                            }
                            .foregroundColor(colors.accent)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colors.accent, lineWidth: 1)
                            )
                        }
                        .padding(.top, 8)
                    }
                    
                    // Sign up button
                    Button(action: {
                        showingSignup = true
                    }) {
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            
                            Text("Sign Up")
                                .fontWeight(.bold)
                                .foregroundColor(colors.accent)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding()
            .onAppear {
                isOfflineMode = !NetworkMonitor.shared.isConnected
                
                // If we're offline and have biometric auth available, prompt for biometric login
                if isOfflineMode && biometricType != .none && UserDefaults.standard.bool(forKey: "has_used_app_before") {
                    // Delay slightly to allow view to appear first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        performBiometricLogin()
                    }
                }
                
                // Mark that the app has been used before
                UserDefaults.standard.set(true, forKey: "has_used_app_before")
            }
            .sheet(isPresented: $showingSignup) {
                SignupView()
                    .environmentObject(authState)
            }
            .sheet(isPresented: $showingPasswordReset) {
                PasswordResetView()
                    .environmentObject(authState)
            }
            .alert(isPresented: $showingBiometricPrompt) {
                Alert(
                    title: Text("Biometric Login Failed"),
                    message: Text(authState.error ?? "Please try again or login with your username and password."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Moved outside of body
    private func performLogin() {
        // Trim whitespace from identifier
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        authState.login(identifier: trimmedIdentifier, password: password, rememberMe: rememberMe) { success, _ in
            if success {
                // Login successful, will be handled by parent view
                // Haptic feedback for success
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                // If biometric auth is available, offer to enable it
                if self.biometricType != .none && self.rememberMe {
                    // Enable biometric auth for next time
                    _ = self.authState.enableBiometricAuth()
                }
            } else {
                // Haptic feedback for error
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    // Moved outside of body
    private func performBiometricLogin() {
        authState.authenticateWithBiometrics { success, errorMessage in
            if success {
                // Login successful, will be handled by parent view
                // Haptic feedback for success
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            } else {
                // Set error and show alert
                authState.error = errorMessage
                showingBiometricPrompt = true
                
                // Haptic feedback for error
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
}

// MARK: - SignupView

/// The signup screen for new users
struct SignupView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var emailConsent = false
    @State private var showingTerms = false
    @State private var usernameValidationMessage: String?
    @State private var emailValidationMessage: String?
    @State private var passwordValidationMessage: String?
    
    // Design
    private let colors = ColorSystem.shared
    
    // Network status
    @State private var isOfflineMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background using ColorSystem
                colors.primaryBackground(for: colorScheme)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo area
                        VStack(spacing: 12) {
                            // App logo
                            Text("decodey")
                                .font(.system(size: 44, weight: .bold, design: .monospaced))
                                .foregroundColor(colors.accent)
                                .padding(.top, 20)
                            
                            Text("Create your account")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 20)
                        
                        // Network warning if offline
                        if isOfflineMode {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Internet connection required for signup")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(colors.warning.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Signup form
                        VStack(spacing: 16) {
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("", text: $username)
                                    .disableAutocorrection(true)
                                    .platformOnChange(of: username) { _ in
                                        validateUsername()
                                    }
                                    .padding()
                                    .background(colors.secondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(usernameValidationMessage == nil ?
                                                   colors.border(for: colorScheme) :
                                                   colors.error,
                                                   lineWidth: 1)
                                    )
                                
                                if let message = usernameValidationMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(colors.error)
                                }
                            }
                            
                            // Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("", text: $email)
                                    .disableAutocorrection(true)
                                    .platformOnChange(of: email) { _ in
                                        validateEmail()
                                    }
                                    .padding()
                                    .background(colors.secondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(emailValidationMessage == nil ?
                                                   colors.border(for: colorScheme) :
                                                   colors.error,
                                                   lineWidth: 1)
                                    )
                                
                                if let message = emailValidationMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(colors.error)
                                }
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("", text: $password)
                                    .platformOnChange(of: password) { _ in
                                        validatePassword()
                                    }
                                    .padding()
                                    .background(colors.secondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(passwordValidationMessage == nil ?
                                                   colors.border(for: colorScheme) :
                                                   colors.error,
                                                   lineWidth: 1)
                                    )
                                
                                if let message = passwordValidationMessage {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(colors.error)
                                }
                            }
                            
                            // Confirm Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("", text: $confirmPassword)
                                    .padding()
                                    .background(colors.secondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(passwordsMatch ?
                                                   colors.border(for: colorScheme) :
                                                   colors.error,
                                                   lineWidth: 1)
                                    )
                                
                                if !passwordsMatch && !confirmPassword.isEmpty {
                                    Text("Passwords do not match")
                                        .font(.caption)
                                        .foregroundColor(colors.error)
                                }
                            }
                            
                            // Email consent toggle
                            Toggle(isOn: $emailConsent) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Marketing Emails")
                                        .font(.subheadline)
                                    
                                    Text("Receive occasional news about new features and promotions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: colors.accent))
                            .padding(.top, 4)
                            
                            // Terms and conditions
                            Button(action: {
                                showingTerms = true
                            }) {
                                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .underline()
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 8)
                            
                            // Error message
                            if let error = authState.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(colors.error)
                                    .padding(.top, 8)
                            }
                            
                            // Sign up button
                            Button(action: performSignup) {
                                if authState.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(colors.accent)
                                        .cornerRadius(8)
                                } else {
                                    Text("Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(signupEnabled ?
                                                   colors.accent :
                                                   colors.accent.opacity(0.5))
                                        .cornerRadius(8)
                                }
                            }
                            .disabled(!signupEnabled || authState.isLoading || isOfflineMode)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
                .onAppear {
                    isOfflineMode = !NetworkMonitor.shared.isConnected
                }
                .sheet(isPresented: $showingTerms) {
                    TermsView()
                }
            }
            // Use platform-agnostic navigation modifiers
            .platformNavigationTitle("")
            .platformNavigationBarLeading(Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
            })
        }
    }
    
    // Computed property to check if passwords match
    private var passwordsMatch: Bool {
        return password == confirmPassword || confirmPassword.isEmpty
    }
    
    // Computed property to check if signup is enabled
    private var signupEnabled: Bool {
        return !username.isEmpty &&
               !email.isEmpty &&
               !password.isEmpty &&
               !confirmPassword.isEmpty &&
               passwordsMatch &&
               usernameValidationMessage == nil &&
               emailValidationMessage == nil &&
               passwordValidationMessage == nil
    }
    
    // Moved outside of body
    private func validateUsername() {
        // Trim whitespace
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        if trimmedUsername.count < 3 {
            usernameValidationMessage = "Username must be at least 3 characters"
            return
        }
        
        // Check for invalid characters
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        if trimmedUsername.rangeOfCharacter(from: allowedCharacterSet.inverted) != nil {
            usernameValidationMessage = "Username can only contain letters, numbers, underscores and hyphens"
            return
        }
        
        // Valid
        usernameValidationMessage = nil
    }
    
    // Moved outside of body
    private func validateEmail() {
        // Trim whitespace
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for @ and .
        if !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            emailValidationMessage = "Please enter a valid email address"
            return
        }
        
        // Valid
        emailValidationMessage = nil
    }
    
    // Moved outside of body
    private func validatePassword() {
        // Check length
        if password.count < 8 {
            passwordValidationMessage = "Password must be at least 8 characters"
            return
        }
        
        // Valid
        passwordValidationMessage = nil
    }
    
    // Moved outside of body
    private func performSignup() {
        // Trim whitespace
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Register
        authState.register(username: trimmedUsername, email: trimmedEmail, password: password, emailConsent: emailConsent) { success, _ in
            if success {
                // Registration successful, will be handled by parent view
                presentationMode.wrappedValue.dismiss()
                
                // Haptic feedback for success
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            } else {
                // Haptic feedback for error
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
}

// MARK: - PasswordResetView

/// View for requesting a password reset
struct PasswordResetView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var resetSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Design
    private let colors = ColorSystem.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                colors.primaryBackground(for: colorScheme)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        // Icon
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(colors.accent)
                            .padding(.top, 40)
                        
                        Text("Reset Your Password")
                            .font(.title2.bold())
                        
                        Text("Enter your email address and we'll send you instructions to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    if resetSent {
                        // Success message
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(colors.success)
                            
                            Text("Reset Link Sent")
                                .font(.headline)
                            
                            Text("Please check your email for instructions to reset your password. The link will expire in 1 hour.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Close")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(colors.accent)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                        }
                    } else {
                        // Reset form
                        VStack(spacing: 16) {
                            // Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("", text: $email)
                                    .disableAutocorrection(true)
                                    .padding()
                                    .background(colors.secondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(colors.border(for: colorScheme), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 24)
                            
                            // Error message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(colors.error)
                                    .padding(.horizontal, 24)
                            }
                            
                            // Send button
                            Button(action: sendResetLink) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(colors.accent)
                                        .cornerRadius(8)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(email.isEmpty ? colors.accent.opacity(0.5) : colors.accent)
                                        .cornerRadius(8)
                                }
                            }
                            .disabled(email.isEmpty || isLoading)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .platformNavigationTitle("")
            .platformNavigationBarLeading(Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Cancel")
            })
        }
    }
    
    // Moved outside of body
    private func sendResetLink() {
        // Trim whitespace
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate email
        guard trimmedEmail.contains("@") && trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Show loading
        isLoading = true
        errorMessage = nil
        
        // Make API request
        let requestData = ["email": trimmedEmail]
        
        ApiService.shared.post(endpoint: "/forgot-password", body: requestData) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Success - show sent message
                    resetSent = true
                    
                    // Haptic feedback
                    #if os(iOS)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                    
                case .failure(let error):
                    // Error
                    errorMessage = error.localizedDescription
                    
                    // Haptic feedback
                    #if os(iOS)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                }
            }
        }
    }
}

// MARK: - TermsView

/// View for displaying the terms and conditions
struct TermsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    // Design
    private let colors = ColorSystem.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.title.bold())
                        .padding(.top)
                    
                    Text("Last Updated: May 9, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Welcome to Decodey!")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("These Terms of Service govern your use of our application Decodey, available on iOS and other platforms. By using our service, you agree to these terms.")
                    
                    Text("1. Acceptance of Terms")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("By accessing or using our service, you agree to be bound by these Terms. If you disagree with any part of the terms, you may not use our service.")
                    
                    Text("2. User Accounts")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("When you create an account with us, you must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account.")
                    
                    Text("3. Privacy Policy")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Please review our Privacy Policy, which also governs your use of our service and explains how we collect, safeguard and disclose information that results from your use of our application.")
                    
                    Text("4. Content")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Our service allows you to play educational cryptography games. The content of these games is provided for entertainment and educational purposes only.")
                    
                    // Add more terms as needed
                    
                    Text("Thank you for using Decodey!")
                        .font(.headline)
                        .padding(.top, 24)
                    
                    Spacer()
                }
                .padding()
            }
            .platformNavigationTitle("Terms & Privacy")
            .platformNavigationBarTrailing(Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
        }
    }
}

// MARK: - BiometricAuth Extensions

/// Extension for integrating Biometric authentication with AuthState
extension AuthState {
    // Enable biometric login for the current user
    func enableBiometricAuth() -> Bool {
        guard let user = user, let accessToken = getAuthToken() else {
            return false
        }
        
        // Store a biometric identifier for this user
        let biometricKey = "biometric_\(user.userId)"
        
        // Store token in keychain with biometric protection
        return KeychainService.shared.setBiometricProtected(key: biometricKey, value: accessToken)
    }
    
    // Authenticate with biometrics
    func authenticateWithBiometrics(completion: @escaping (Bool, String?) -> Void) {
        // Check if user is already authenticated
        if isAuthenticated {
            completion(true, nil)
            return
        }
        
        // Check if biometric data is available
        guard let userData = UserDefaults.standard.data(forKey: "cached_user_data"),
              let user = try? JSONDecoder().decode(User.self, from: userData) else {
            let errorMessage = "No cached user data available for biometric login"
            completion(false, errorMessage)
            return
        }
        
        // Build biometric key for this user
        let biometricKey = "biometric_\(user.userId)"
        
        // Check if we have a token stored for this biometric key
        guard KeychainService.shared.getBiometricProtected(key: biometricKey) != nil else {
            let errorMessage = "No biometric login data found"
            completion(false, errorMessage)
            return
        }
        
        // Perform biometric authentication
        BiometricAuthHelper.shared.authenticateWithBiometrics(reason: "Log in to Decodey") { result in
            switch result {
            case .success:
                // Authentication successful, attempt to load session data
                self.user = user
                self.isAuthenticated = true
                self.isOfflineMode = !NetworkMonitor.shared.isConnected
                
                // Get a fresh token from keychain (in case it was updated)
                self.accessToken = KeychainService.shared.get(key: KeychainKeys.accessToken)
                
                // Report success
                completion(true, nil)
                
            case .failure(let error):
                // Authentication failed
                let errorMessage = error.localizedDescription
                completion(false, errorMessage)
            }
        }
    }
}

// MARK: - KeychainService Extension for Biometrics

/// Extension of KeychainService for biometric protection
extension KeychainService {
    // Store a value with biometric protection
    func setBiometricProtected(key: String, value: String) -> Bool {
        if let data = value.data(using: .utf8) {
            return setBiometricProtectedData(key: key, value: data)
        }
        return false
    }
    
    // Store data with biometric protection
    func setBiometricProtectedData(key: String, value: Data) -> Bool {
        let context = LAContext()
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        // Create access control
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryAny,
            nil
        ) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessControl as String: accessControl,
            kSecUseAuthenticationContext as String: context
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Get a value with biometric protection
    func getBiometricProtected(key: String) -> String? {
        if let data = getBiometricProtectedData(key: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // Get data with biometric protection
    func getBiometricProtectedData(key: String) -> Data? {
        let context = LAContext()
        context.localizedReason = "Authenticate to access your account"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
}
