import SwiftUI

// A simple settings model to store user preferences
class UserSettings: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var showTextHelpers: Bool {
        didSet {
            UserDefaults.standard.set(showTextHelpers, forKey: "showTextHelpers")
        }
    }
    
    @Published var useAccessibilityTextSize: Bool {
        didSet {
            UserDefaults.standard.set(useAccessibilityTextSize, forKey: "useAccessibilityTextSize")
        }
    }
    
    init() {
        // Load saved settings or use defaults
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.showTextHelpers = UserDefaults.standard.bool(forKey: "showTextHelpers")
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: "useAccessibilityTextSize")
        
        // If this is the first launch, set default values
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            self.isDarkMode = true // Default to dark mode
            UserDefaults.standard.set(true, forKey: "isDarkMode")
        }
        
        if UserDefaults.standard.object(forKey: "showTextHelpers") == nil {
            self.showTextHelpers = true // Default to showing text helpers
            UserDefaults.standard.set(true, forKey: "showTextHelpers")
        }
        
        if UserDefaults.standard.object(forKey: "useAccessibilityTextSize") == nil {
            self.useAccessibilityTextSize = false // Default to standard text size
            UserDefaults.standard.set(false, forKey: "useAccessibilityTextSize")
        }
    }
}

//
//  UserSettings.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

