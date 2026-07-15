//
//  KeychainManager.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.beamapp.token"
    private let account = "userToken"
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Save token to Keychain
    func saveToken(_ token: String) throws {
        #if DEBUG
        print("🔐 Attempting to save token to Keychain: \(token.prefix(10))...")
        #endif
        
        // Delete existing token
        try deleteToken()
        
        // Convert token to Data
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Create Keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
        
        // Save to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Token saved to Keychain successfully")
        } else {
            print("❌ Keychain save failed: \(status)")
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Fetch token from Keychain
    func fetchToken() -> String? {
        print("🔍 Searching for token in Keychain...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let tokenData = result as? Data,
               let token = String(data: tokenData, encoding: .utf8) {
                #if DEBUG
                print("✅ Found token in Keychain: \(token.prefix(10))...")
                #endif
                return token
            }
        } else if status == errSecItemNotFound {
            print("🔍 No token in Keychain")
        } else {
            print("❌ Keychain search failed: \(status)")
        }
        
        return nil
    }
    
    /// Delete token from Keychain
    func deleteToken() throws {
        print("🗑️ Attempting to delete token from Keychain...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Token deleted from Keychain")
        } else {
            print("❌ Keychain delete failed: \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Check whether a token exists
    func hasToken() -> Bool {
        return fetchToken() != nil
    }
    
    /// Check whether the token is valid (JWT expiration check)
    func isTokenValid() -> Bool {
        guard let token = fetchToken() else {
            return false
        }
        
        // Check JWT token expiration time
        return !isTokenExpired(token)
    }
    
    /// Check JWT token expiration time
    private func isTokenExpired(_ token: String) -> Bool {
        let components = token.components(separatedBy: ".")
        
        guard components.count == 3,
              let payloadData = Data(base64Encoded: components[1].padding(toLength: ((components[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            print("❌ Failed to parse JWT token")
            return true
        }
        
        let currentTime = Date().timeIntervalSince1970
        let isExpired = currentTime >= exp
        
        if isExpired {
            print("⏰ Token has expired: \(Date(timeIntervalSince1970: exp))")
        } else {
            let remainingTime = exp - currentTime
            let remainingHours = remainingTime / 3600
            print("⏰ Time remaining until token expires: \(String(format: "%.1f", remainingHours)) hours")
        }
        
        return isExpired
    }
    
    /// Time remaining until token expiration (seconds)
    func getTokenExpirationTime() -> TimeInterval? {
        guard let token = fetchToken() else {
            return nil
        }
        
        let components = token.components(separatedBy: ".")
        
        guard components.count == 3,
              let payloadData = Data(base64Encoded: components[1].padding(toLength: ((components[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        return exp - currentTime
    }
}

// MARK: - Keychain Errors
enum KeychainError: Error, LocalizedError {
    case invalidData
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Token data is invalid."
        case .saveFailed(let status):
            return "Keychain save failed: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(status)"
        case .unknown:
            return "An unknown Keychain error occurred."
        }
    }
}

// MARK: - String Extensions
extension String {
    func truncate(to length: Int) -> String {
        return (self.count > length) ? self.prefix(length) + "..." : self
    }
}

