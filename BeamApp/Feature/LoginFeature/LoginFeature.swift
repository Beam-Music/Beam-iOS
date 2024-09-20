//
//  LoginFeature.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//
import ComposableArchitecture
import Foundation

struct LoginFeature: Reducer {
    struct State: Equatable {
        var username: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var token: String?
    }
    
    enum Action: Equatable {
        case usernameChanged(String)
        case passwordChanged(String)
        case loginButtonTapped
        case loginResponse(TaskResult<String>)
    }
    
    @Dependency(\.authService) var authService
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .usernameChanged(username):
            state.username = username
            return .none
            
        case let .passwordChanged(password):
            state.password = password
            return .none
            
        case .loginButtonTapped:
            state.isLoading = true
            state.errorMessage = nil
            return .run { [username = state.username, password = state.password] send in
                await send(.loginResponse(TaskResult {
                    try await self.authService.login(username, password)
                }))
            }
            
        case let .loginResponse(.success(token)):
            state.isLoading = false
            state.token = token
            return .none
            
        case let .loginResponse(.failure(error)):
            state.isLoading = false
            if let loginError = error as? LoginError {
                switch loginError {
                case .invalidCredentials:
                    state.errorMessage = "Invalid username or password"
                case .serverError:
                    state.errorMessage = "Server error occurred. Please try again later."
                case .networkError:
                    state.errorMessage = "Network error occurred. Please check your connection."
                default:
                    state.errorMessage = "An unexpected error occurred"
                }
            } else {
                state.errorMessage = error.localizedDescription
            }
            return .none
        }
    }
}

