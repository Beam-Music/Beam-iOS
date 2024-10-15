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
        var fullName: String = ""
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }

    enum Action: Equatable {
        case fullNameChanged(String)
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
            case let .fullNameChanged(fullName):
                state.fullName = fullName
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

                return .run { [fullName = state.fullName, email = state.email, password = state.password] send in
                    do {
                        let success = try await signupRequest(fullName, email, password)
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
    static var liveValue: (String, String, String) async throws -> Bool = { fullName, email, password in
        // 실제 서버로의 회원가입 요청 구현
        // 성공 시 true 반환, 실패 시 에러 던짐
        return true
    }
}

