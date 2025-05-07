import Foundation

struct Game {
    //Game state
    var encrypted: String
    var solution: String
    var currentDisplay: String
    var selectedLetter: String?
    var mistakes: Int
    var maxMistakes:Int
    var hasWon: Bool
    var hasLost: Bool
    
    //Game ID for db ref
    var gameId: String?
    
    //mapping dictionaries
    var mapping: [Character:Character]
    var correctMappings: [Character:Character]
    
    var letterFrequency: [Character:Int]
    
    //guessed mappings
    var guessedMappings: [Character:Character]
    //timestamp tracking
    var startTime: Date
    var lastUpdateTime: Date
    // difficulty level
    var difficulty: String
    // Initialize with default values for a new game
    init() {
        // Default initialization
        self.encrypted = ""
        self.solution = ""
        self.currentDisplay = ""
        self.selectedLetter = nil
        self.mistakes = 0
        self.maxMistakes = 7 // Default value
        self.hasWon = false
        self.hasLost = false
        self.gameId = nil
        self.mapping = [:]
        self.correctMappings = [:]
        self.letterFrequency = [:]
        self.guessedMappings = [:]
        self.startTime = Date()
        self.lastUpdateTime = Date()
        self.difficulty = "medium"
        
        // Create a new game with a random quote
        setupNewGame()
    }
    mutating func setupNewGame() {
        do {
            //Get a random quote from the db
            let (quoteText, quoteAuthor,_) = try DatabaseManager.shared.getRandomQuote()
            
            //Set the solution and the difficulty
            self.solution = quoteText.uppercaased()
            self.difficulty = "medium"
            self.maxMistakes = difficultyToMaxMistakes(self.difficulty)
            
            //Set up the Game
            setupGameWithSolution(solution)
            
        } catch {
            print("Error loading quote from database: \(error)")
            self.solution = "MANNERS MAKETH MAN"
            setupGameWithSolution(solution)
        }
            
            
        }
    //Converts difficulty string to max mistakes int
    private func difficultyToMaxMistakes(_ difficulty: String) -> Int {
        switch difficulty {
        case "easy":
            return 8
        case "medium":
            return 5
        case "hard":
            return 3
        default:
            return 5
        }
    }
    
    // Set up a game with a given solution
    mutating func setupGameWithSolution(_ solution: String) {
        //Generate a mapping for encrytion
        var mapping: [Character: Character] = [:]
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let shuffled = alphabet.shuffled()
        
        for i in 0..<alphabet.count {
            mapping[alphabet[i]]=shuffled[i]
        }
        //Create reverse mapping for verification
        correctMappings = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        
        //Encrypt the solution
        encrypted = solution.map { char in
            if char.isLetter{
                return String(mapping[char] ?? char)
            }
            return String(char)
        }.joined()
        
        //Initialize display with blocks
        currentDisplay = solution.map {char in
            if char.isLetter{
                return "█"
            }
            return String(char)
        }.joined()
        
        // Calculate letter frequency
        letterFrequency = [:]
        for char in encrypted where char.isLetter {
            letterFrequency[char, default: 0] += 1
        }
        
        //Reset other game state
        self.mapping = mapping
        self.guessedMappings = [:]
        self.selectedLetter = nil
        self.mistakes = 0
        self.hasWon = false
        self.hasLost = false
        self.startTime = Date()
        self.lastUpdateTime = Date()
        
    }
    
    // Select letter for guessing
    mutating func selectLetter(_ letter: Character) {
        // Don't allow selecting of already guessed letters
        if correctlyGuessed().contains(letter) {
            selectedLetter = nil
            return
        }
    }
    
    mutating func makeGuess(_ guessedLetter: Character) -> Bool {
        guard let selectedLetter = selectedLetter else {
            return false
        }
        
        //Check if guess is correct
        let isCorrect = correctMappings[selected] == guessedLetter
         if isCorrect {
            //Store the mapping
             guessedMappings[selected] = guessedLetter
             
             //Update display
             updateDisplay()
             
             //Check if we've won
             checkWinCondition()
         } else {
             //Increment mistakes
             mistakes += 1
             
             // Check if we've lost
             if mistakes >= maxMistakes {
                 hasLost = true
             }
         }
        
        // Clear selection after guess
        selectedLetter = nil
        
        // Update last update time
        lastUpdateTime = Date()
        
        // Save the game state to teh database
        saveGameState()
        
        return isCorrect
    }
    
    //Update display text based on guessed mappings
    mutating func updateDisplay() {
        var displayChars = Array(currentDisplay)
        
        for i in 0..<encrypted.count {
            let encryptedChar = Array(encrypted)[i]
            
            if let guessedChar = guessedMappings[encryptedChar]{
                displayChars[i] = guessedChar
            }
        }
        currentDisplay = String(displayChars)
    }
    
    //Check if all letters have been correctly guessed
    mutating func checkWinCondition() {
        let uniqueEncryptedLetters = Set(encrypted.filter { $0.isLetter})
        let guessedLetters = Set(guessedMappings.keys)
        
        hasWon = uniqueEncryptedLetters == guessedLetters
    }
    
    // Get the set of correctly guessed letters
    func correctlyGuessed() -> [Character] {
        return Array(guessedMappings.keys)
    }

    // Get the set of unique encrypted letters
    func uniqueEncryptedLetters() -> [Character] {
        return Array(Set(encrypted.filter { $0.isLetter })).sorted()
    }
    
    // Get a hint by revealing a random letter
    mutating func getHint() -> Bool {
        //Get all unguessed encrypted letters
        let unguessedLetters = Set(encrypted.filter { $0.isLetter && !correctlyGuessed().contains($0)})
        // If all letters are guessed, we can't provide a hint
        if unguessedLetters.isEmpty {
            return false
        }
        //Pick a random unguessed letter
        if let hintLetter = unguessedLetters.randomElement() {
            // Get the corresponding original letter
            let originalLetter = correctMappings[hintLetter] ?? "?"
             // Update the mapping
            guessedMappings[hintLetter] = originalLetter
            // Update Display
            updateDisplay()
            //Increment mistakes
            mistakes += 1
            //Check for win condition
            checkWinCondition()
            //Check for loss
            if mistakes >= maxMistakes {
                hasLost = true
            }
            // Save the game state
            saveGameState()
            
            return true
            
        }
        return false
    }
    
    // Calculate score based on difficulty, mistakes and time
    func CalculateScore() -> Int {
        let timeInSeconds = Int(lastUpdateTime.timeIntervalSince(startTime))
        
        // Base score dependson difficulty
        let baseScore: Int
        switch difficulty.lowercased() {
        case "easy":
            baseScore = 100
        case "hard":
            baseScore = 300
        default:
            baseScore = 200
        }
        
        let timeScore: Int
        if timeInSeconds < 60 { // Under 1 minute
            timeScore = 50
        } else if timeInSeconds < 180 { // Under 3 minutes
            timeScore = 30
        } else if timeInSeconds < 300 { // Under 5 minutes
            timeScore = 10
        } else if timeInSeconds > 600 { // Over 10 minutes
            timeScore = -20
        } else {
            timeScore = 0
        }
        
        // Calculate total score
        let totalScore = baseScore - mistakePenalty + timeScore
        
        // Ensure score is never negative
        return max(0, totalScore)
    }
    
    // Private method to save game state
    private func saveGameState() {
        do {
            if let gameId = self.gameId {
                //Update existing game
                try DatabaseManager.shared.updateGame(se;f, gameID: gameId)
            } else {
                // Save new game
                try DatabaseManager.shared.saveGame(self)
            }
        } catch {
            print("error saving game state: \(error)")
        }
    }
    
    // Static method to load most recent game
    static func loadSavedGame() -> Game? {
        do {
            return try DatabaseManager.shared.loadLatestGame()
        } catch {
            print("error loading saved game: \(error)")
            return nil
        }
    }
}

    
    






//
//  Game.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

