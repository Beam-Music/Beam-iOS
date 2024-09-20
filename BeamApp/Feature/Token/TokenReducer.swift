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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .saveToken(token):
            do {
                try tokenStorage.saveToken(token)
                state.token = token
            } catch {
                print("토큰 저장 실패: \(error)")
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
                print("토큰 삭제 실패: \(error)")
            }
            return .none
        }
    }
}

