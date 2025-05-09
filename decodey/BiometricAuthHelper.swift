import Foundation
import LocalAuthentication

/// Helper class for biometric authentication
class BiometricAuthHelper {
    // Singleton instance
    static let shared = BiometricAuthHelper()
    
    // Error domain
    private let errorDomain = "com.decodey.BiometricAuthHelper"
    
    private init() {}
    
    // Check if biometric authentication is available
    func biometricAuthAvailable() -> (Bool, String) {
        let context = LAContext()
        var authError: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
        
        if canEvaluate {
            let biometryType = context.biometryType
            
            switch biometryType {
            case .faceID:
                return (true, "Face ID")
            case .touchID:
                return (true, "Touch ID")
            default:
                return (false, "None")
            }
        } else {
            // Get error description
            let errorDescription: String
            if let error = authError {
                errorDescription = error.localizedDescription
            } else {
                errorDescription = "Biometric authentication not available"
            }
            
            return (false, errorDescription)
        }
    }
    
    // Authenticate using biometrics
    func authenticateWithBiometrics(reason: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let context = LAContext()
        var authError: NSError?
        
        // Check if can evaluate policy
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            // Fall back to device passcode if available
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                authenticateWithPasscode(reason: reason, context: context, completion: completion)
                return
            }
            
            // Handle error
            if let error = authError {
                completion(.failure(error))
            } else {
                let error = NSError(domain: errorDomain,
                                     code: LAError.biometryNotAvailable.rawValue,
                                     userInfo: [NSLocalizedDescriptionKey: "Biometric authentication not available"])
                completion(.failure(error))
            }
            return
        }
        
        // Authenticate with biometrics
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    let error = NSError(domain: self.errorDomain,
                                         code: LAError.authenticationFailed.rawValue,
                                         userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Fallback to device passcode
    private func authenticateWithPasscode(reason: String, context: LAContext, completion: @escaping (Result<Bool, Error>) -> Void) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    let error = NSError(domain: self.errorDomain,
                                         code: LAError.authenticationFailed.rawValue,
                                         userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Helper to determine what biometric type is available
    func getBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    // Biometric types
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var description: String {
            switch self {
            case .none:
                return "None"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none:
                return "exclamationmark.shield"
            case .touchID:
                return "touchid"
            case .faceID:
                return "faceid"
            }
        }
    }
}

//
//  BiometricAuthHelper.swift
//  decodey
//
//  Created by Daniel Horsley on 09/05/2025.
//

