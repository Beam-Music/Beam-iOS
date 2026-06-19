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
            let trimmedEmail = AuthValidation.normalizedEmail(state.email)
            guard !trimmedEmail.isEmpty, !state.password.isEmpty else {
                state.errorMessage = "이메일과 비밀번호를 입력해 주세요."
                state.isLoading = false
                return .none
            }
            guard AuthValidation.isValidEmail(trimmedEmail) else {
                state.errorMessage = "올바른 이메일 형식을 입력해 주세요."
                state.isLoading = false
                return .none
            }
            state.isLoading = true
            state.errorMessage = nil
            state.email = trimmedEmail
            return .run { [email = trimmedEmail, password = state.password] send in
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
                    state.errorMessage = "이메일 또는 비밀번호가 올바르지 않습니다."
                case .serverError, .invalidResponse:
                    state.errorMessage = "서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
                case .networkError:
                    state.errorMessage = "네트워크 오류가 발생했습니다. 인터넷 연결을 확인해 주세요."
                case .emailNotVerified:
                    state.errorMessage = "이메일 인증을 먼저 완료해 주세요."
                default:
                    state.errorMessage = "알 수 없는 오류가 발생했습니다."
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

