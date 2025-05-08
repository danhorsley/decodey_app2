import AVFoundation
import SwiftUI

/// SoundManager provides a centralized system for playing game sounds with Apple best practices
class SoundManager: ObservableObject {
    // MARK: - Singleton
    static let shared = SoundManager()
    
    // MARK: - Published Properties
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled")
        }
    }
    
    @Published var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            updateVolume()
        }
    }
    
    // MARK: - Sound Types
    enum SoundType: String {
        case letterClick = "letter_click"
        case correctGuess = "correct_guess"
        case incorrectGuess = "incorrect_guess"
        case hint = "hint"
        case win = "win"
        case lose = "lose"
        
        var filename: String {
            return "\(rawValue).wav"
        }
    }
    
    // MARK: - Private Properties
    
    // Audio engine for high performance sound playback
    private var audioEngine: AVAudioEngine
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private var audioFiles: [SoundType: AVAudioFile] = [:]
    private var audioPlayerNodes: [SoundType: AVAudioPlayerNode] = [:]
    
    // Simple queue system to prevent sound overlaps
    private var isPlaying: [SoundType: Bool] = [:]
    private var shouldPlay: Bool {
        // Check system conditions
        #if os(iOS)
        return isSoundEnabled && !AVAudioSession.sharedInstance().isOtherAudioPlaying
        #else
        return isSoundEnabled
        #endif
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load user preferences
        self.isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
        if UserDefaults.standard.object(forKey: "isSoundEnabled") == nil {
            // Default to enabled if preference doesn't exist
            self.isSoundEnabled = true
            UserDefaults.standard.set(true, forKey: "isSoundEnabled")
        }
        
        // Load volume settings
        self.volume = UserDefaults.standard.float(forKey: "soundVolume")
        if UserDefaults.standard.object(forKey: "soundVolume") == nil {
            // Default volume
            self.volume = 0.5
            UserDefaults.standard.set(0.5, forKey: "soundVolume")
        }
        
        // Initialize audio engine
        self.audioEngine = AVAudioEngine()
        
        // Setup audio session
        setupAudioSession()
        
        // Preload sound files
        preloadSounds()
        
        // Configure audio engine
        setupAudioEngine()
        
        // Register for interruptions
        registerForNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Play a sound effect
    /// - Parameter type: The type of sound to play
    func play(_ type: SoundType) {
        // Check if sound is enabled and if we're not already playing this sound
        guard shouldPlay, !(isPlaying[type] ?? false) else { return }
        
        // Use queue to safely access audio APIs
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // Mark sound as playing
            self.isPlaying[type] = true
            
            // Determine which approach to use based on sound type
            if type == .win || type == .lose {
                // For longer sounds, use AVAudioPlayer
                self.playWithAudioPlayer(type)
            } else {
                // For short effects, use AVAudioEngine with player nodes
                self.playWithAudioEngine(type)
            }
        }
    }
    
    /// Stop all sounds
    func stopAllSounds() {
        // Stop all audio players
        for player in audioPlayers.values {
            player.stop()
        }
        
        // Stop all player nodes
        for playerNode in audioPlayerNodes.values {
            playerNode.stop()
        }
        
        // Reset playing state
        for type in SoundType.allCases {
            isPlaying[type] = false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            // Configure audio session for game sounds
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func preloadSounds() {
        // Preload using both methods for flexibility
        preloadWithAudioPlayers()
        preloadWithAudioEngine()
    }
    
    private func preloadWithAudioPlayers() {
        for type in SoundType.allCases {
            if let path = Bundle.main.path(forResource: type.rawValue, ofType: "wav") {
                let url = URL(fileURLWithPath: path)
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = volume
                    audioPlayers[type] = player
                } catch {
                    print("Failed to preload sound \(type.rawValue): \(error.localizedDescription)")
                }
            } else {
                print("Sound file not found: \(type.rawValue).wav")
            }
        }
    }
    
    private func preloadWithAudioEngine() {
        for type in SoundType.allCases {
            if let url = Bundle.main.url(forResource: type.rawValue, withExtension: "wav") {
                do {
                    let file = try AVAudioFile(forReading: url)
                    audioFiles[type] = file
                    
                    // Create player node
                    let playerNode = AVAudioPlayerNode()
                    audioEngine.attach(playerNode)
                    
                    // Connect to main mixer
                    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: file.processingFormat)
                    
                    // Store player node
                    audioPlayerNodes[type] = playerNode
                } catch {
                    print("Failed to preload audio file \(type.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setupAudioEngine() {
        do {
            // Start the audio engine
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func playWithAudioPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type] else { return }
        
        // Reset player
        player.currentTime = 0
        player.volume = volume
        
        // Play sound
        player.play()
        
        // Add completion handler to update state
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying[type] = false
        }
    }
    
    private func playWithAudioEngine(_ type: SoundType) {
        guard let playerNode = audioPlayerNodes[type],
              let file = audioFiles[type] else {
            // Fallback to AVAudioPlayer if engine setup failed
            playWithAudioPlayer(type)
            return
        }
        
        // Set volume
        playerNode.volume = volume
        
        // Schedule file to play from beginning
        do {
            // Schedule buffer to play
            try playerNode.scheduleFile(file, at: nil) { [weak self] in
                // Mark as no longer playing when complete
                DispatchQueue.main.async {
                    self?.isPlaying[type] = false
                }
            }
            
            // Start player node if needed
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            print("Failed to schedule audio file: \(error)")
            isPlaying[type] = false
        }
    }
    
    private func updateVolume() {
        // Update volume for all players
        for player in audioPlayers.values {
            player.volume = volume
        }
        
        // Update volume for all player nodes
        for playerNode in audioPlayerNodes.values {
            playerNode.volume = volume
        }
    }
    
    private func registerForNotifications() {
        #if os(iOS)
        // Register for interruptions (calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Register for route changes (headphones, bluetooth)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began - pause all sounds
            stopAllSounds()
        } else if type == .ended {
            // Interruption ended - check if we should resume
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                // Resume audio engine
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try audioEngine.start()
                } catch {
                    print("Failed to restart audio after interruption: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Restart engine on route changes to handle Bluetooth switches
        do {
            try audioEngine.start()
        } catch {
            print("Failed to restart audio after route change: \(error.localizedDescription)")
        }
    }
    #endif
}

// Extension to make SoundType iterable
extension SoundManager.SoundType: CaseIterable {}

//
//  SoundManager.swift
//  decodey
//
//  Created by Daniel Horsley on 08/05/2025.
//

