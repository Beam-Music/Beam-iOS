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
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var token: String?
    }
    
    enum Action: Equatable {
        case emailChanged(String)
        case passwordChanged(String)
        case loginButtonTapped
        case loginResponse(TaskResult<String>)
        case reset
    }
    
    @Dependency(\.authService) var authService
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .emailChanged(email):
            state.email = email
            return .none
            
        case let .passwordChanged(password):
            state.password = password
            return .none
            
        case .loginButtonTapped:
            state.isLoading = true
            state.errorMessage = nil
            return .run { [email = state.email, password = state.password] send in
                await send(.loginResponse(TaskResult {
                    try await self.authService.login(email, password)
                }))
            }
            
        case let .loginResponse(.success(token)):
            state.isLoading = false
            state.token = token
            if let userId = SignupFeature.parseUserIdFromJWT(token) {
                UserDefaults.standard.set(userId, forKey: "userID")
                print("✅ userID 저장됨: \(userId)")
            } else {
                print("❌ userID 파싱 실패: token=\(token.prefix(20))...")
            }
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
                case .emailNotVerified:
                    state.errorMessage = "이메일 인증을 먼저 완료해 주세요."
                default:
                    state.errorMessage = "An unexpected error occurred"
                }
            } else {
                state.errorMessage = error.localizedDescription
            }
            return .none
            
        case .reset:
            state = State()
            return .none
        }
    }
}

