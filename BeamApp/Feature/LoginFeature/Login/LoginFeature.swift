//
//  LoginFeature.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//
import ComposableArchitecture
import Foundation

private enum LoginAuthValidation {
    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}

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
            let trimmedEmail = LoginAuthValidation.normalizedEmail(state.email)
            guard !trimmedEmail.isEmpty, !state.password.isEmpty else {
                state.errorMessage = "Enter your email and password."
                state.isLoading = false
                return .none
            }
            guard LoginAuthValidation.isValidEmail(trimmedEmail) else {
                state.errorMessage = "Enter a valid email address."
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
                print("✅ userID saved: \(userId)")
            } else {
                print("❌ Failed to parse userID: token=\(token.prefix(20))...")
            }
            return .none
            
        case let .loginResponse(.failure(error)):
            state.isLoading = false
            if let loginError = error as? LoginError {
                switch loginError {
                case .invalidCredentials:
                    state.errorMessage = "Email or password is incorrect."
                case .serverError, .invalidResponse:
                    state.errorMessage = "A server error occurred. Please try again later."
                case .networkError:
                    state.errorMessage = "A network error occurred. Check your internet connection."
                case .emailNotVerified:
                    state.errorMessage = "Please verify your email first."
                default:
                    state.errorMessage = "An unknown error occurred."
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
