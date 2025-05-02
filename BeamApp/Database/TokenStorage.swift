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
        print("🔵 Attempting to save token: \(token.prefix(10))...")
        
        // Delete existing tokens first
        try deleteAllTokens()
        
        let newToken = TokenEntity(token: token)
        print("🟢 Created new token entity")
        
        // Insert the new token
        container.mainContext.insert(newToken)
        
        do {
            try container.mainContext.save()
            print("🟢 Token saved successfully")
        } catch {
            print("🔴 Failed to save token: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func fetchToken() -> String? {
        do {
            let descriptor = FetchDescriptor<TokenEntity>()
            
            let result = try container.mainContext.fetch(descriptor)
            print("🟡 Fetched token count: \(result.count)")
            if let token = result.first?.token {
                print("🟢 Token found: \(token.prefix(10))...")
                return token
            } else {
                print("🔴 No token found in storage")
                return nil
            }
        } catch {
            print("🔴 Failed to fetch token: \(error)")
            return nil
        }
    }
    
    // Delete All Tokens
    @MainActor
    func deleteAllTokens() throws {
        print("🔵 Attempting to delete all tokens...")
        
        do {
            let descriptor = FetchDescriptor<TokenEntity>()
            let tokens = try container.mainContext.fetch(descriptor)
            print("🟡 Found \(tokens.count) tokens to delete")
            
            for token in tokens {
                container.mainContext.delete(token)
                print("🟢 Deleting token: \(token.token.prefix(10))...")
            }
            
            try container.mainContext.save()
            print("🟢 Successfully deleted all tokens")
        } catch {
            print("🔴 Failed to delete tokens: \(error)")
            throw error
        }
    }
    
    @MainActor
    func hasValidToken() -> Bool {
        fetchToken() != nil
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
        set { self[TokenStorageKey.self] = newValue }
    }
} 
