//
//  TokenReducer.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//

import ComposableArchitecture

struct TokenReducer: Reducer {
    struct State: Equatable {
        var token: String?
    }

    enum Action: Equatable {
        case saveToken(String)
        case loadToken
        case deleteToken
    }

    @Dependency(\.tokenStorage) var tokenStorage

    @MainActor func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .saveToken(token):
            do {
                try tokenStorage.saveToken(token)
                state.token = token
            } catch {
                print("Failed to save token: \(error)")
            }
            return .none

        case .loadToken:
//            state.token = tokenStorage.fetchToken()
            return .none

        case .deleteToken:
            do {
//                try tokenStorage.deleteToken()
                state.token = nil
            } catch {
                print("Failed to delete token: \(error)")
            }
            return .none
        }
    }
}
