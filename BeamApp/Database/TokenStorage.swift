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
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }
    
    @MainActor
    func saveToken(_ token: String) throws {
        let newToken = TokenEntity(token: token)
        print(newToken, "newtoken")
//        context.insert(newToken)
        do {
            try context.transaction {
                context.insert(newToken)
            }
            try context.save()
            print("Token saved successfully.")
        } catch {
            print("Failed to save token: \(error.localizedDescription)")
            throw error
        }
        try context.save()
    }

    func fetchToken() -> String? {
            do {
                let result = try context.fetch(FetchDescriptor<TokenEntity>())
                        return result.first?.token
            } catch {
                print("토큰 가져오기 실패: \(error)")
                return nil
            }
        }
    
//    // Delete Token
//    func deleteToken() throws {
//        do {
//            let result = try context.fetch(Query.fetch(TokenEntity.self))
//            if let tokenEntity = result.first {
//                context.delete(tokenEntity)
//                try context.save()
//            }
//        } catch {
//            print("Failed to delete token: \(error)")
//        }
//    }
}

//struct TokenStorageKey: DependencyKey {
//    @MainActor
//    static var liveValue: TokenStorage {
//        let container = try! ModelContainer(for: TokenEntity.self)
//        return TokenStorage(context: container.mainContext)
//    }
//}
struct TokenStorageKey: DependencyKey {
    @MainActor
    static var liveValue: TokenStorage {
        do {
            // ModelContainer가 정상적으로 초기화되는지 확인
            let container = try ModelContainer(for: TokenEntity.self)
            return TokenStorage(context: container.mainContext)
        } catch {
            fatalError("ModelContainer 초기화 실패: \(error)")
        }
    }
}

extension DependencyValues {
    var tokenStorage: TokenStorage {
        get { self[TokenStorageKey.self] }
        set { self[TokenStorageKey.self] = newValue }
    }
}
