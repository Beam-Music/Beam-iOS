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
        print("🔵 토큰 저장 시도: \(token.prefix(10))...")
        #endif
        
        do {
            // 1. Keychain에 저장 (주 저장소)
            try keychainManager.saveToken(token)
            print("✅ Keychain에 토큰 저장 성공")
            
            // 2. SwiftData에도 백업 저장 (선택사항)
            try saveTokenToSwiftData(token)
            print("✅ SwiftData에 토큰 백업 저장 성공")
            
        } catch {
            print("🔴 토큰 저장 실패: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func fetchToken() -> String? {
        print("🔍 토큰 검색 중...")
        
        // 1. Keychain에서 먼저 검색
        if let token = keychainManager.fetchToken() {
            // 토큰 유효성 확인
            if keychainManager.isTokenValid() {
                #if DEBUG
                print("✅ Keychain에서 유효한 토큰 발견: \(token.prefix(10))...")
                #endif
                return token
            } else {
                print("⏰ 토큰이 만료됨, 삭제 중...")
                try? keychainManager.deleteToken()
                try? deleteAllTokensFromSwiftData()
                return nil
            }
        }
        
        // 2. Keychain에 없으면 SwiftData에서 검색 (마이그레이션용)
        if let token = fetchTokenFromSwiftData() {
            print("🔄 SwiftData에서 토큰 발견, Keychain으로 마이그레이션...")
            try? keychainManager.saveToken(token)
            return token
        }
        
        print("🔴 저장된 토큰이 없음")
        return nil
    }
    
    // Delete All Tokens
    @MainActor
    func deleteAllTokens() throws {
        print("🔵 모든 토큰 삭제 시도...")
        
        do {
            // 1. Keychain에서 삭제
            try keychainManager.deleteToken()
            print("✅ Keychain에서 토큰 삭제 성공")
            
            // 2. SwiftData에서도 삭제
            try deleteAllTokensFromSwiftData()
            print("✅ SwiftData에서 토큰 삭제 성공")
            
        } catch {
            print("🔴 토큰 삭제 실패: \(error)")
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
        // 기존 토큰 삭제
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
                print("🔄 SwiftData에서 토큰 발견: \(token.prefix(10))...")
                #endif
                return token
            }
        } catch {
            print("🔴 SwiftData에서 토큰 검색 실패: \(error)")
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
            print("🔴 SwiftData에서 토큰 삭제 실패: \(error)")
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
