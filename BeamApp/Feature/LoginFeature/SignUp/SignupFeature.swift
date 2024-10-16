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
        var verificationCode: String = ""
        var isLoading: Bool = false
        var isVerified: Bool = false
        var isLoggedIn: Bool = false
        var errorMessage: String? = nil
    }
    
    enum Action: Equatable {
        case usernameChanged(String)
        case emailChanged(String)
        case passwordChanged(String)
        case verificationCodeChanged(String)
        case signupButtonTapped
        case verifyButtonTapped
        case signupResponse(Result<Bool, SignupError>)
        case verifyResponse(Result<Bool, SignupError>)
        case setIsLoggedIn(Bool)
    }
    
    struct Environment {
        var signupRequest: (String, String, String) async throws -> Bool
        var verifyRequest: (String, String, String) async throws -> Bool
    }
    
    enum SignupError: Error, Equatable {
        case invalidResponse
        case serverError(String)
    }
    
    @Dependency(\.signupRequest) var signupRequest
    @Dependency(\.verifyRequest) var verifyRequest: (String, String) async throws -> Bool

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
                
            case let .verificationCodeChanged(code):
                state.verificationCode = code
                return .none  
                
            case .signupButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [username = state.username, email = state.email, password = state.password] send in
                    do {
                        let success = try await signupRequest(username, email, password)
                        await send(.signupResponse(.success(success)))
                    } catch {
                        await send(.signupResponse(.failure(.serverError(error.localizedDescription))))
                    }
                }
                
            case let .signupResponse(.success(success)):
                state.isLoading = false
                if success {
                    // 회원가입 성공 시 필요한 로직 추가 가능
                }
                return .none
                
            case let .signupResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .verifyButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [email = state.email, code = state.verificationCode] send in
                    do {
                        let success = try await verifyRequest(email, code)
                        await send(.verifyResponse(.success(success)))
                    } catch {
                        await send(.verifyResponse(.failure(.serverError(error.localizedDescription))))
                    }
                }
                
            case let .verifyResponse(.success(success)):
                state.isLoading = false
                if success {
                    state.isVerified = true
                    return .send(.setIsLoggedIn(true))
                }
                return .none
                
            case let .verifyResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .setIsLoggedIn(isLoggedIn):
                state.isLoggedIn = isLoggedIn
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
    var verifyRequest: (String, String) async throws -> Bool {
            get { self[VerifyRequestKey.self] }
            set { self[VerifyRequestKey.self] = newValue }
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

private struct VerifyRequestKey: DependencyKey {
    static var liveValue: (String, String) async throws -> Bool = { email, code in
        var request = URLRequest(url: URL(string: Endpoints.Auth.verify)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return true
    }
}


