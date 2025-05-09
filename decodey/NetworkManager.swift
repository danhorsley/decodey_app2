import Foundation
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import Foundation.NSHost  // For Host class
#endif

/// NetworkManager handles all API communication for the decodey app
class NetworkManager {
    // MARK: - Singleton
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private let baseURL: URL
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // Store the auth token
    private var authToken: String? {
        didSet {
            // Update UserDefaults when token changes
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "authToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "authToken")
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Configure URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json"]
        self.session = URLSession(configuration: configuration)
        
        // Set base URL from configuration
        #if DEBUG
        self.baseURL = URL(string: "http://localhost:5000/api")!
        #else
        self.baseURL = URL(string: "https://uncryptgame.com/api")!
        #endif
        
        // Load existing token if available
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
    }
    
    // MARK: - Authentication Methods
    
    /// Set the authentication token
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    /// Clear the authentication token (logout)
    func clearAuthToken() {
        self.authToken = nil
    }
    
    /// Check if a user is authenticated
    var isAuthenticated: Bool {
        return authToken != nil
    }
    
    // MARK: - Common Response Models
    
    /// Common error response structure
    struct APIError: Codable, Error {
        let error: String
    }
    
    // MARK: - API Models
    
    // Leaderboard models
    struct LeaderboardEntry: Codable, Identifiable {
        let id: Int
        let user_id: String
        let username: String
        let rank: Int
        let score: Int
        let games_played: Int
        let games_won: Int
    }
    
    struct LeaderboardResponse: Codable {
        let entries: [LeaderboardEntry]
        let period_type: String
        let period_start: String
        let period_end: String
        let current_user_rank: Int?
    }
    
    // User stats model
    struct UserStats: Codable {
        let games_played: Int
        let games_won: Int
        let win_percentage: Double
        let current_streak: Int
        let best_streak: Int
        let total_score: Int
        let average_score: Int
        let average_mistakes: Double
        let average_time: Double
        let last_played_date: String?
    }
    
    // Daily challenge model
    struct DailyChallenge: Codable {
        let game_id: String
        let encrypted_paragraph: String
        let display: String
        let letter_frequency: [String: Int]
        let is_available: Bool
        let already_completed: Bool
        let completion_data: CompletionData?
    }
    
    struct CompletionData: Codable {
        let score: Int
        let mistakes: Int
        let time_taken: Int
        let completed_at: String
    }
    
    // MARK: - API Methods
    
    /// Fetch the leaderboard
    /// - Parameters:
    ///   - period: The leaderboard period - "weekly" or "all_time"
    ///   - completion: Callback with the result
    func fetchLeaderboard(period: String = "weekly", completion: @escaping (Result<LeaderboardResponse, Error>) -> Void) {
        // Build URL
        let url = baseURL.appendingPathComponent("leaderboard")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "period", value: period)]
        
        // Create request
        var request = URLRequest(url: components.url!)
        
        // Add auth token if available
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Make the request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LeaderboardResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { leaderboard in
                    completion(.success(leaderboard))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Fetch user statistics
    /// - Parameter completion: Callback with the result
    func fetchUserStats(completion: @escaping (Result<UserStats, Error>) -> Void) {
        // Ensure user is authenticated
        guard let token = authToken else {
            completion(.failure(NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        // Build URL
        let url = baseURL.appendingPathComponent("user_stats")
        
        // Create request
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Make the request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: UserStats.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { stats in
                    completion(.success(stats))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Fetch the daily challenge
    /// - Parameter completion: Callback with the result
    func fetchDailyChallenge(completion: @escaping (Result<DailyChallenge, Error>) -> Void) {
        // Build URL
        let url = baseURL.appendingPathComponent("get_daily")
        
        // Create request
        var request = URLRequest(url: url)
        
        // Add auth token if available (not required but helps identify the user)
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add app identifier
        request.addValue("iOS-App/1.0", forHTTPHeaderField: "User-Agent")
        
        // Make the request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: DailyChallenge.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { challenge in
                    completion(.success(challenge))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Send offline games to the server
    /// - Parameters:
    ///   - games: Array of completed game data
    ///   - completion: Callback with the result
    func syncOfflineGames(games: [CompletedGameData], completion: @escaping (Result<Bool, Error>) -> Void) {
        // Build URL
        let url = baseURL.appendingPathComponent("save_appgames")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add auth token if available
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Device identifier for anonymous users
        let deviceId = getDeviceIdentifier()
        request.addValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        
        // Serialize the data
        do {
            request.httpBody = try JSONEncoder().encode(games)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Make the request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> Bool in
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let success = json?["success"] as? Bool, success {
                    return true
                } else if let errorMessage = json?["error"] as? String {
                    throw NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                } else {
                    throw NSError(domain: "NetworkManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { success in
                    completion(.success(success))
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Platform-specific helpers
    
    /// Get a unique device identifier
    func getDeviceIdentifier() -> String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        // On macOS, generate a persistent UUID stored in user defaults
        let defaults = UserDefaults.standard
        if let storedId = defaults.string(forKey: "deviceIdentifier") {
            return storedId
        } else {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: "deviceIdentifier")
            return newId
        }
        #else
        return UUID().uuidString
        #endif
    }
    
    /// Get the device model
    func getDeviceModel() -> String {
        #if os(iOS)
        return UIDevice.current.model
        #elseif os(macOS)
        // Get Mac model
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return "Unknown Device"
        #endif
    }
    
    /// Get the OS version
    func getOSVersion() -> String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        #else
        return "Unknown OS"
        #endif
    }
}

// MARK: - Support Models

/// Data structure for a completed game to be synced
struct CompletedGameData: Codable {
    let game_id: String
    let solution: String
    let mistakes: Int
    let time_taken: Int
    let score: Int
    let is_daily: Bool
    let completed_at: String
    let device_info: DeviceInfo
    
    struct DeviceInfo: Codable {
        let model: String
        let os_version: String
        let app_version: String
        
        static func current() -> DeviceInfo {
            // Get app version
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            
            return DeviceInfo(
                model: NetworkManager.shared.getDeviceModel(),
                os_version: NetworkManager.shared.getOSVersion(),
                app_version: appVersion
            )
        }
    }
}
