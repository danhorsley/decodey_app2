import Foundation
import Security

// MARK: - Models for Authentication

/// User model matching the server-side schema
struct User: Codable {
    let userId: String
    let username: String
    let email: String
    var emailConsent: Bool
    var consentDate: Date?
    var isSubadmin: Bool
    
    // Computed property for display name
    var displayName: String {
        username
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case email
        case emailConsent = "email_consent"
        case consentDate = "consent_date"
        case isSubadmin = "subadmin"
    }
}

/// Auth state to track user's authentication status
class AuthState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var user: User?
    @Published var error: String?
    @Published var isOfflineMode = false
    
    // Token management
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    
    // Singleton instance
    static let shared = AuthState()
    
    private init() {
        // Check for cached authentication on startup
        checkForExistingAuth()
    }
    
    // Check if we have an existing authentication in the keychain
    private func checkForExistingAuth() {
        // Background checking to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Try to get tokens from keychain
            if let accessToken = KeychainService.shared.get(key: KeychainKeys.accessToken),
               let tokenExpirationString = KeychainService.shared.get(key: KeychainKeys.tokenExpiration),
               let expirationDate = ISO8601DateFormatter().date(from: tokenExpirationString),
               expirationDate > Date() {
                
                // Valid token found
                self.accessToken = accessToken
                
                // Get refresh token if available
                self.refreshToken = KeychainService.shared.get(key: KeychainKeys.refreshToken)
                self.tokenExpiration = expirationDate
                
                // Get cached user data
                if let userData = UserDefaults.standard.data(forKey: "cached_user_data"),
                   let user = try? JSONDecoder().decode(User.self, from: userData) {
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.user = user
                        self.isAuthenticated = true
                        self.isOfflineMode = !NetworkMonitor.shared.isConnected
                    }
                } else {
                    // Token is valid but no user data
                    self.clearAuth()
                }
            } else {
                // No valid token found
                self.clearAuth()
            }
        }
    }
    
    // Login user with server
    func login(identifier: String, password: String, rememberMe: Bool, completion: @escaping (Bool, String?) -> Void) {
        // Reset error
        error = nil
        isLoading = true
        
        // Check network connectivity
        guard NetworkMonitor.shared.isConnected else {
            // Try offline login
            tryOfflineLogin(identifier: identifier, password: password, completion: completion)
            return
        }
        
        // Set up request
        let loginData = [
            "username": identifier,
            "password": password,
            "rememberMe": rememberMe
        ] as [String: Any]
        
        // Make API request
        ApiService.shared.post(endpoint: "/login", body: loginData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let data):
                    // Parse login response
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let accessToken = json["access_token"] as? String,
                       let username = json["username"] as? String,
                       let userId = json["user_id"] as? String {
                        
                        // Store tokens
                        self?.accessToken = accessToken
                        
                        // Store refresh token if remember me is checked
                        if rememberMe, let refreshToken = json["refresh_token"] as? String {
                            self?.refreshToken = refreshToken
                            KeychainService.shared.set(key: KeychainKeys.refreshToken, value: refreshToken)
                        }
                        
                        // Calculate token expiration (default to 30 days)
                        let expiryDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
                        self?.tokenExpiration = expiryDate
                        
                        // Store in keychain
                        KeychainService.shared.set(key: KeychainKeys.accessToken, value: accessToken)
                        KeychainService.shared.set(key: KeychainKeys.tokenExpiration, value: ISO8601DateFormatter().string(from: expiryDate))
                        
                        // Create user object
                        let isSubadmin = json["subadmin"] as? Bool ?? false
                        let user = User(
                            userId: userId,
                            username: username,
                            email: identifier.contains("@") ? identifier : "unknown@example.com",
                            emailConsent: false,
                            consentDate: nil,
                            isSubadmin: isSubadmin
                        )
                        
                        // Cache user data for offline use
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "cached_user_data")
                        }
                        
                        // Store password hash for offline login
                        if rememberMe {
                            self?.storeOfflineCredentials(username: identifier, password: password)
                        }
                        
                        // Update auth state
                        self?.user = user
                        self?.isAuthenticated = true
                        self?.isOfflineMode = false
                        
                        completion(true, nil)
                    } else {
                        let errorMessage = "Could not parse login response"
                        self?.error = errorMessage
                        completion(false, errorMessage)
                    }
                    
                case .failure(let error):
                    let errorMessage = error.localizedDescription
                    self?.error = errorMessage
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    // Try offline login when no network available
    private func tryOfflineLogin(identifier: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Get stored credentials
        guard let storedCredentialData = KeychainService.shared.getData(key: "offline_credentials"),
              let storedUserData = UserDefaults.standard.data(forKey: "cached_user_data") else {
            // No stored credentials
            isLoading = false
            let errorMessage = "Cannot login offline without previous online authentication"
            error = errorMessage
            completion(false, errorMessage)
            return
        }
        
        // Parse stored credentials
        do {
            let credentials = try JSONDecoder().decode([OfflineCredential].self, from: storedCredentialData)
            
            // Find matching credential
            if let matchingCredential = credentials.first(where: { $0.username.lowercased() == identifier.lowercased() || $0.email.lowercased() == identifier.lowercased() }),
               matchingCredential.validatePassword(password) {
                
                // Valid offline login
                if let user = try? JSONDecoder().decode(User.self, from: storedUserData) {
                    // Update auth state for offline mode
                    self.user = user
                    self.isAuthenticated = true
                    self.isOfflineMode = true
                    
                    // Since we're offline, we'll use a temporary token
                    self.accessToken = "offline_temp_token"
                    self.tokenExpiration = Date().addingTimeInterval(24 * 60 * 60) // 1 day
                    
                    isLoading = false
                    completion(true, nil)
                } else {
                    isLoading = false
                    let errorMessage = "Could not parse cached user data"
                    error = errorMessage
                    completion(false, errorMessage)
                }
            } else {
                // Invalid credentials
                isLoading = false
                let errorMessage = "Invalid credentials for offline login"
                error = errorMessage
                completion(false, errorMessage)
            }
        } catch {
            // Error parsing credentials
            isLoading = false
            let errorMessage = "Error parsing stored credentials: \(error.localizedDescription)"
            self.error = errorMessage
            completion(false, errorMessage)
        }
    }
    
    // Register a new user
    func register(username: String, email: String, password: String, emailConsent: Bool, completion: @escaping (Bool, String?) -> Void) {
        // Reset error
        error = nil
        isLoading = true
        
        // Must have network for registration
        guard NetworkMonitor.shared.isConnected else {
            isLoading = false
            let errorMessage = "Cannot register without internet connection"
            error = errorMessage
            completion(false, errorMessage)
            return
        }
        
        // Set up request data
        let registerData = [
            "username": username,
            "email": email,
            "password": password,
            "emailConsent": emailConsent
        ] as [String: Any]
        
        // Make API request
        ApiService.shared.post(endpoint: "/signup", body: registerData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    // Registration successful, now log in
                    self?.login(identifier: email, password: password, rememberMe: true, completion: completion)
                    
                case .failure(let error):
                    // Registration failed
                    let errorMessage = error.localizedDescription
                    self?.error = errorMessage
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    // Log out the current user
    func logout(completion: (() -> Void)? = nil) {
        // Check if we're online and have a token
        if NetworkMonitor.shared.isConnected, let token = accessToken, !token.hasPrefix("offline") {
            // Make API request to invalidate token on server
            ApiService.shared.post(endpoint: "/logout", body: [:]) { _ in
                // Clear auth regardless of server response
                self.clearAuth()
                completion?()
            }
        } else {
            // Offline logout, just clear local auth
            clearAuth()
            completion?()
        }
    }
    
    // Clear authentication state
    private func clearAuth() {
        // Clear tokens
        accessToken = nil
        refreshToken = nil
        tokenExpiration = nil
        
        // Clear keychain data
        KeychainService.shared.delete(key: KeychainKeys.accessToken)
        KeychainService.shared.delete(key: KeychainKeys.refreshToken)
        KeychainService.shared.delete(key: KeychainKeys.tokenExpiration)
        
        // Don't clear offline credentials to allow future offline login
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.user = nil
            self.isOfflineMode = false
        }
    }
    
    // Store credentials for offline login
    private func storeOfflineCredentials(username: String, password: String) {
        guard let user = user else { return }
        
        // Create secure hash of password
        let credential = OfflineCredential(username: user.username, email: user.email, passwordHash: hashPassword(password))
        
        // Get existing credentials
        var credentials: [OfflineCredential] = []
        if let data = KeychainService.shared.getData(key: "offline_credentials"),
           let existingCredentials = try? JSONDecoder().decode([OfflineCredential].self, from: data) {
            credentials = existingCredentials
            
            // Remove existing credential for this user if present
            credentials.removeAll { $0.username == user.username || $0.email == user.email }
        }
        
        // Add new credential
        credentials.append(credential)
        
        // Save updated credentials
        if let newData = try? JSONEncoder().encode(credentials) {
            KeychainService.shared.setData(key: "offline_credentials", value: newData)
        }
    }
    
    // Hash a password for offline storage
    private func hashPassword(_ password: String) -> String {
        // For simplicity we're using a basic hash
        // In a real app, use a more secure method like PBKDF2
        return password.sha256()
    }
    
    // Get the current auth token (for API requests)
    func getAuthToken() -> String? {
        // Check if we need to refresh the token
        if let expiration = tokenExpiration, expiration.timeIntervalSinceNow < 60 * 60 {
            // Less than an hour left, try to refresh if we're online
            if NetworkMonitor.shared.isConnected {
                refreshTokenIfNeeded()
            }
        }
        
        return accessToken
    }
    
    // Refresh the token if needed
    private func refreshTokenIfNeeded() {
        guard let refreshToken = refreshToken, NetworkMonitor.shared.isConnected else {
            return
        }
        
        // Make refresh token request
        let refreshRequest = ["refresh_token": refreshToken]
        
        ApiService.shared.post(endpoint: "/refresh", body: refreshRequest) { [weak self] result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let newToken = json["access_token"] as? String {
                    
                    // Update token
                    self?.accessToken = newToken
                    
                    // Calculate new expiration (default to 30 days)
                    let newExpiry = Date().addingTimeInterval(30 * 24 * 60 * 60)
                    self?.tokenExpiration = newExpiry
                    
                    // Store in keychain
                    KeychainService.shared.set(key: KeychainKeys.accessToken, value: newToken)
                    KeychainService.shared.set(key: KeychainKeys.tokenExpiration, value: ISO8601DateFormatter().string(from: newExpiry))
                }
                
            case .failure:
                // If refresh fails, we don't immediately log out
                // Let the user continue until a server request explicitly fails with auth error
                break
            }
        }
    }
    
    // Check if user is offline
    func isOffline() -> Bool {
        return !NetworkMonitor.shared.isConnected
    }
}

// MARK: - Helper Models

/// Model for storing offline credentials
struct OfflineCredential: Codable {
    let username: String
    let email: String
    let passwordHash: String
    
    func validatePassword(_ password: String) -> Bool {
        return password.sha256() == passwordHash
    }
}

/// Keys for the keychain
struct KeychainKeys {
    static let accessToken = "decodey_access_token"
    static let refreshToken = "decodey_refresh_token"
    static let tokenExpiration = "decodey_token_expiration"
}

// MARK: - Extensions

extension String {
    // Simple SHA256 hash function for password storage
    func sha256() -> String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Network Monitoring

/// Simple network monitor to track connection status
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    static let shared = NetworkMonitor()
    
    private init() {
        // In a real app, implement network monitoring
        // For now, just assume we're connected
        checkConnection()
    }
    
    func checkConnection() {
        // Simulate network check
        // In a real app, use NWPathMonitor for actual network status
        isConnected = true
    }
}

// MARK: - Keychain Service

/// Service for securely storing sensitive data in the Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    func set(key: String, value: String) -> Bool {
        if let data = value.data(using: .utf8) {
            return setData(key: key, value: data)
        }
        return false
    }
    
    func get(key: String) -> String? {
        if let data = getData(key: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func setData(key: String, value: Data) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: value
        ] as [String: Any]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getData(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    func delete(key: String) {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Service

/// Service for making API requests
class ApiService {
    static let shared = ApiService()
    
    // Base URL for API
    private let baseURL = "https://api.decodey.game" // Replace with your actual API URL
    
    private init() {}
    
    // Make a POST request to the API
    func post(endpoint: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        // Create URL
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(ApiError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = AuthState.shared.getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    // Error response from server
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let message = json["msg"] as? String {
                        completion(.failure(ApiError.serverError(message, httpResponse.statusCode)))
                    } else {
                        completion(.failure(ApiError.httpError(httpResponse.statusCode)))
                    }
                    return
                }
            }
            
            // Return data
            if let data = data {
                completion(.success(data))
            } else {
                completion(.failure(ApiError.noData))
            }
        }
        
        task.resume()
    }
    
    // Make a GET request to the API
    func get(endpoint: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Create URL
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(ApiError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add auth token if available
        if let token = AuthState.shared.getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Make request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    // Error response from server
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let message = json["msg"] as? String {
                        completion(.failure(ApiError.serverError(message, httpResponse.statusCode)))
                    } else {
                        completion(.failure(ApiError.httpError(httpResponse.statusCode)))
                    }
                    return
                }
            }
            
            // Return data
            if let data = data {
                completion(.success(data))
            } else {
                completion(.failure(ApiError.noData))
            }
        }
        
        task.resume()
    }
    
    // API-specific errors
    enum ApiError: Error, LocalizedError {
        case invalidURL
        case httpError(Int)
        case serverError(String, Int)
        case noData
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .httpError(let code):
                return "HTTP Error: \(code)"
            case .serverError(let message, let code):
                return "\(message) (Error \(code))"
            case .noData:
                return "No data received"
            }
        }
    }
}

//
//  AuthenticationModels.swift
//  decodey
//
//  Created by Daniel Horsley on 09/05/2025.
//

