//
//  TokenStorage.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//

import SwiftData
import SwiftUI
import Dependencies

class TokenStorage {
    static let shared = TokenStorage()
    private let keychainManager = KeychainManager.shared
    
    // SwiftData는 백업용으로 유지 (선택사항)
    var container: ModelContainer
    
    init() {
        do {
            let schema = Schema([TokenEntity.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: TokenEntity.self, configurations: modelConfiguration)
            print("TokenStorage initialized successfully")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    @MainActor
    func saveToken(_ token: String) throws {
        #if DEBUG
        print("🔵 Attempting to save token: \(token.prefix(10))...")
        #endif
        
        do {
            // 1. Save to Keychain (주 Save소)
            try keychainManager.saveToken(token)
            print("✅ Token saved to Keychain")
            
            // 2. SwiftData에도 백업 Save (선택사항)
            try saveTokenToSwiftData(token)
            print("✅ Token backup saved to SwiftData")
            
        } catch {
            print("🔴 Failed to save token: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func fetchToken() -> String? {
        print("🔍 Searching for token...")
        
        // 1. Keychain에서 먼저 검색
        if let token = keychainManager.fetchToken() {
            // 토큰 유효성 OK
            if keychainManager.isTokenValid() {
                #if DEBUG
                print("✅ Valid token found in Keychain: \(token.prefix(10))...")
                #endif
                return token
            } else {
                print("⏰ Token has expired, deleting...")
                try? keychainManager.deleteToken()
                try? deleteAllTokensFromSwiftData()
                return nil
            }
        }
        
        // 2. Keychain에 없으면 SwiftData에서 검색 (마이그레이션용)
        if let token = fetchTokenFromSwiftData() {
            print("🔄 Token found in SwiftData, migrating to Keychain...")
            try? keychainManager.saveToken(token)
            return token
        }
        
        print("🔴 No saved token")
        return nil
    }
    
    // Delete All Tokens
    @MainActor
    func deleteAllTokens() throws {
        print("🔵 Attempting to delete all tokens...")
        
        do {
            // 1. Keychain에서 Delete
            try keychainManager.deleteToken()
            print("✅ Token deleted from Keychain")
            
            // 2. SwiftData에서도 Delete
            try deleteAllTokensFromSwiftData()
            print("✅ Token deleted from SwiftData")
            
        } catch {
            print("🔴 Failed to delete token: \(error)")
            throw error
        }
    }
    
    @MainActor
    func hasValidToken() -> Bool {
        return keychainManager.isTokenValid()
    }
    
    // MARK: - SwiftData Backup Methods
    
    @MainActor
    private func saveTokenToSwiftData(_ token: String) throws {
        // Delete existing token
        try deleteAllTokensFromSwiftData()
        
        let newToken = TokenEntity(token: token)
        container.mainContext.insert(newToken)
        
        try container.mainContext.save()
    }
    
    @MainActor
    private func fetchTokenFromSwiftData() -> String? {
        do {
            let descriptor = FetchDescriptor<TokenEntity>()
            let result = try container.mainContext.fetch(descriptor)
            
            if let token = result.first?.token {
                #if DEBUG
                print("🔄 Token found in SwiftData: \(token.prefix(10))...")
                #endif
                return token
            }
        } catch {
            print("🔴 Failed to search token in SwiftData: \(error)")
        }
        
        return nil
    }
    
    @MainActor
    private func deleteAllTokensFromSwiftData() throws {
        do {
            let descriptor = FetchDescriptor<TokenEntity>()
            let tokens = try container.mainContext.fetch(descriptor)
            
            for token in tokens {
                container.mainContext.delete(token)
            }
            
            try container.mainContext.save()
        } catch {
            print("🔴 Failed to delete token from SwiftData: \(error)")
            throw error
        }
    }
}

struct TokenStorageKey: DependencyKey {
    @MainActor
    static var liveValue: TokenStorage {
        TokenStorage.shared
    }
}

extension DependencyValues {
    var tokenStorage: TokenStorage {
        get { self[TokenStorageKey.self] }
        set { self[TokenStorageKey.self] }
    }
} 
