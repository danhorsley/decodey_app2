import Foundation
import Combine

// MARK: - Sync Operation Types

/// Types of operations that can be queued for sync
enum SyncOperationType: String, Codable {
    case gameComplete
    case userSettings
}

/// Structure representing a sync operation
struct SyncOperation: Codable {
    let id: String
    let type: SyncOperationType
    let data: [String: Any]
    let timestamp: Date
    
    // For Codable support, since Dictionary<String, Any> isn't directly Codable
    private struct CodableData: Codable {
        let key: String
        let value: AnyCodable
    }
    
    private var codableData: [CodableData] {
        data.map { CodableData(key: $0.key, value: AnyCodable($0.value)) }
    }
    
    init(type: SyncOperationType, data: [String: Any], timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, codableData, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SyncOperationType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode dictionary
        let decodedData = try container.decode([CodableData].self, forKey: .codableData)
        data = Dictionary(uniqueKeysWithValues: decodedData.map { ($0.key, $0.value.value) })
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(codableData, forKey: .codableData)
    }
}

// Helper for encoding/decoding Any
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull, is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            // Convert to string as fallback
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - OfflineSyncService

/// Service to handle syncing offline game data when connection is restored
class OfflineSyncService {
    // Singleton instance
    static let shared = OfflineSyncService()
    
    // Queue of operations to perform when online
    private var syncQueue: [SyncOperation] = []
    
    // Subscription to network monitor
    private var networkSubscription: AnyCancellable?
    
    // Is currently syncing
    private var isSyncing = false
    
    // Notification center for sync events
    let syncNotification = NotificationCenter()
    
    private init() {
        // Load any saved sync operations from disk
        loadSyncQueue()
        
        // Subscribe to network changes
        networkSubscription = NetworkMonitor.shared.$isConnected.sink { [weak self] isConnected in
            if isConnected {
                // When back online, attempt to sync
                self?.attemptSync()
            }
        }
    }
    
    // Add a game result to the sync queue
    func queueGameForSync(game: Game) {
        // Create sync operation
        let operation = SyncOperation(
            type: .gameComplete,
            data: [
                "game_id": game.gameId ?? UUID().uuidString,
                "solution": game.solution,
                "mistakes": game.mistakes,
                "score": game.calculateScore(),
                "time_taken": Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
                "has_won": game.hasWon,
                "difficulty": game.difficulty
            ],
            timestamp: Date()
        )
        
        // Add to queue
        syncQueue.append(operation)
        
        // Save queue
        saveSyncQueue()
        
        // Attempt sync if online
        if NetworkMonitor.shared.isConnected {
            attemptSync()
        }
    }
    
    // Queue user settings changes for sync
    func queueSettingsForSync(settings: UserSettings) {
        // Create sync operation with settings data
        let operation = SyncOperation(
            type: .userSettings,
            data: [
                "theme": settings.isDarkMode ? "dark" : "light",
                "showTextHelpers": settings.showTextHelpers,
                "useAccessibilityTextSize": settings.useAccessibilityTextSize
            ],
            timestamp: Date()
        )
        
        // Add to queue
        syncQueue.append(operation)
        
        // Save queue
        saveSyncQueue()
        
        // Attempt sync if online
        if NetworkMonitor.shared.isConnected {
            attemptSync()
        }
    }
    
    // Attempt to sync all queued operations
    private func attemptSync() {
        // Don't start sync if we're already syncing
        guard !isSyncing, !syncQueue.isEmpty else {
            return
        }
        
        // Mark as syncing
        isSyncing = true
        
        // Post notification that sync started
        syncNotification.post(name: .syncStarted, object: nil)
        
        // Process operations one by one
        processSyncQueue()
    }
    
    // Process the sync queue
    private func processSyncQueue() {
        // Make sure we're still online
        guard NetworkMonitor.shared.isConnected else {
            isSyncing = false
            syncNotification.post(name: .syncFailed, object: nil, userInfo: ["reason": "No network connection"])
            return
        }
        
        // Get next operation
        guard !syncQueue.isEmpty else {
            // No more operations, we're done
            isSyncing = false
            syncNotification.post(name: .syncCompleted, object: nil)
            return
        }
        
        // Get the next operation
        let operation = syncQueue[0]
        
        // Process based on type
        switch operation.type {
        case .gameComplete:
            syncGameCompletion(operation) { [weak self] success in
                if success {
                    // Remove the operation from the queue
                    self?.syncQueue.removeFirst()
                    self?.saveSyncQueue()
                }
                
                // Continue with next operation
                self?.processSyncQueue()
            }
            
        case .userSettings:
            syncUserSettings(operation) { [weak self] success in
                if success {
                    // Remove the operation from the queue
                    self?.syncQueue.removeFirst()
                    self?.saveSyncQueue()
                }
                
                // Continue with next operation
                self?.processSyncQueue()
            }
        }
    }
    
    // Sync a game completion
    private func syncGameCompletion(_ operation: SyncOperation, completion: @escaping (Bool) -> Void) {
        // Make sure we're authenticated
        guard let token = AuthState.shared.getAuthToken(), !token.hasPrefix("offline") else {
            // Not authenticated properly, need user to log in first
            isSyncing = false
            syncNotification.post(name: .syncFailed, object: nil, userInfo: ["reason": "Not authenticated"])
            completion(false)
            return
        }
        
        // Make API request to save game
        ApiService.shared.post(endpoint: "/api/save_appgames", body: operation.data) { result in
            switch result {
            case .success:
                // Success
                print("Successfully synced game completion")
                completion(true)
                
            case .failure(let error):
                // Failure - if server error, try again later
                print("Failed to sync game completion: \(error.localizedDescription)")
                
                // If token expired or auth error, stop syncing until user logs in again
                if let apiError = error as? ApiService.ApiError, apiError.isAuthError {
                    self.isSyncing = false
                    self.syncNotification.post(name: .syncFailed, object: nil, userInfo: ["reason": "Authentication error"])
                    completion(false)
                } else {
                    // For other errors like network issues, try again later
                    completion(false)
                }
            }
        }
    }
    
    // Sync user settings
    private func syncUserSettings(_ operation: SyncOperation, completion: @escaping (Bool) -> Void) {
        // Make sure we're authenticated
        guard let token = AuthState.shared.getAuthToken(), !token.hasPrefix("offline") else {
            // Not authenticated properly, need user to log in first
            isSyncing = false
            completion(false)
            return
        }
        
        // Make API request to save settings
        ApiService.shared.post(endpoint: "/api/update_settings", body: operation.data) { result in
            switch result {
            case .success:
                // Success
                print("Successfully synced user settings")
                completion(true)
                
            case .failure(let error):
                // Failure
                print("Failed to sync user settings: \(error.localizedDescription)")
                
                // If token expired or auth error, stop syncing
                if let apiError = error as? ApiService.ApiError, apiError.isAuthError {
                    self.isSyncing = false
                    completion(false)
                } else {
                    // For other errors, try again later
                    completion(false)
                }
            }
        }
    }
    
    // Save the sync queue to disk
    private func saveSyncQueue() {
        do {
            let data = try JSONEncoder().encode(syncQueue)
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("sync_queue.json")
            
            try data.write(to: fileURL)
            print("Saved sync queue to disk")
        } catch {
            print("Error saving sync queue: \(error.localizedDescription)")
        }
    }
    
    // Load the sync queue from disk
    private func loadSyncQueue() {
        do {
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("sync_queue.json")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                syncQueue = try JSONDecoder().decode([SyncOperation].self, from: data)
                print("Loaded \(syncQueue.count) operations from sync queue")
            }
        } catch {
            print("Error loading sync queue: \(error.localizedDescription)")
            syncQueue = []
        }
    }
    
    // Get the number of pending sync operations
    var pendingOperationCount: Int {
        return syncQueue.count
    }
    
    // Check if syncing is in progress
    var isSyncInProgress: Bool {
        return isSyncing
    }
    
    // Force sync (if online)
    func forceSync() {
        if NetworkMonitor.shared.isConnected && !syncQueue.isEmpty {
            attemptSync()
        }
    }
    
    // Clear the sync queue (for testing or resolving errors)
    func clearSyncQueue() {
        syncQueue = []
        saveSyncQueue()
    }
}

// MARK: - ApiService Extension

extension ApiService.ApiError {
    // Helper to check if an error is authentication-related
    var isAuthError: Bool {
        switch self {
        case .httpError(let code), .serverError(_, let code):
            return code == 401 || code == 403
        default:
            return false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let syncStarted = Notification.Name("com.decodey.syncStarted")
    static let syncCompleted = Notification.Name("com.decodey.syncCompleted")
    static let syncFailed = Notification.Name("com.decodey.syncFailed")
}
