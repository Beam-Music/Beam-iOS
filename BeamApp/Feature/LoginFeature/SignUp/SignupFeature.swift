//
//  SignupFeature.swift
//  BeamApp
//
//  Created by freed on 10/15/24.
//

import ComposableArchitecture
import Foundation

struct SignupFeature: Reducer {
    struct State: Equatable {
        var username: String = ""
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }

    enum Action: Equatable {
        case usernameChanged(String)
        case emailChanged(String)
        case passwordChanged(String)
        case signupButtonTapped
        case signupResponse(Result<Bool, SignupError>)
    }

    struct Environment {
        var signupRequest: (String, String, String) async throws -> Bool
    }

    enum SignupError: Error, Equatable {
        case invalidResponse
        case serverError(String)
    }

    @Dependency(\.signupRequest) var signupRequest

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .usernameChanged(username):
                state.username = username
                return .none
                
            case let .emailChanged(email):
                state.email = email
                return .none
                
            case let .passwordChanged(password):
                state.password = password
                return .none

            case .signupButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                return .run { [username = state.username, email = state.email, password = state.password] send in
                    do {
                        let success = try await signupRequest(username, email, password)
                        await send(.signupResponse(.success(success)))
                    } catch {
                        // 에러 처리
                        await send(.signupResponse(.failure(.serverError(error.localizedDescription))))
                    }
                }

            case let .signupResponse(.success(success)):
                state.isLoading = false
                if success {
                    // 회원가입 성공 시 추가 로직 (예: 로그인 페이지로 이동)
                }
                return .none

            case let .signupResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}

extension DependencyValues {
    var signupRequest: (String, String, String) async throws -> Bool {
        get { self[SignupRequestKey.self] }
        set { self[SignupRequestKey.self] = newValue }
    }
}

private struct SignupRequestKey: DependencyKey {
    static var liveValue: (String, String, String) async throws -> Bool = { username, email, password in
        var request = URLRequest(url: URL(string: Endpoints.Auth.register)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }

        return true
    }
}

