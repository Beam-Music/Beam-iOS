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
        var phone: String = ""
        var verificationCode: String = ""
        var isLoading: Bool = false
        var isVerified: Bool = false
        var isLoggedIn: Bool = false
        var errorMessage: String? = nil
        var showVerificationSection: Bool = false
        var token: String? = nil
    }
    
    enum Action: Equatable {
        case usernameChanged(String)
        case emailChanged(String)
        case passwordChanged(String)
        case phoneChanged(String)
        case verificationCodeChanged(String)
        case signupButtonTapped
        case verifyButtonTapped
        case signupResponse(Result<SignupResponseType, SignupError>)
        case verifyResponse(Result<VerifyResponseType, SignupError>)
        case setIsLoggedIn(Bool)
    }
    
    enum SignupResponseType: Equatable {
        case newUser
        case existingUnverifiedUser
    }
    
    enum VerifyResponseType: Equatable {
        case success(token: String)
    }
    
    enum SignupError: Error, Equatable {
        case invalidResponse
        case serverError(String)
        case internalServerError(String)
        case emailServiceError
        
        var localizedDescription: String {
            switch self {
            case .invalidResponse:
                return "서버 응답이 올바르지 않습니다."
            case .serverError(let message):
                return message
            case .internalServerError(let message):
                if message.contains("SendGrid") {
                    return "현재 이메일 서비스에 일시적인 문제가 있습니다.\n잠시 후 다시 시도해주세요."
                }
                return "서버 내부 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
            case .emailServiceError:
                return "이메일 서비스에 일시적인 문제가 있습니다.\n잠시 후 다시 시도해주세요."
            }
        }
    }
    
    @Dependency(\.signupRequest) var signupRequest
    @Dependency(\.verifyRequest) var verifyRequest
    @Dependency(\.tokenStorage) var tokenStorage
    
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
                
            case let .phoneChanged(phone):
                state.phone = phone
                return .none
                
            case let .verificationCodeChanged(code):
                state.verificationCode = code
                return .none
                
            case .signupButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [username = state.username, email = state.email, password = state.password] send in
                    do {
                        let response = try await signupRequest(username, email, password)
                        await send(.signupResponse(.success(response)))
                    } catch {
                        if let signupError = error as? SignupError {
                            await send(.signupResponse(.failure(signupError)))
                        } else {
                            await send(.signupResponse(.failure(.serverError(error.localizedDescription))))
                        }
                    }
                }
                
            case let .signupResponse(.success(response)):
                state.isLoading = false
                state.showVerificationSection = true
                switch response {
                case .newUser:
                    state.errorMessage = "인증 메일이 발송되었습니다. 이메일을 확인해주세요."
                case .existingUnverifiedUser:
                    state.errorMessage = "이미 가입된 이메일입니다. 새로운 인증 코드가 발송되었으니 이메일을 확인해주세요."
                }
                return .none
                
            case let .signupResponse(.failure(error)):
                state.isLoading = false
                if error.localizedDescription.contains("이미 인증된 이메일") {
                    state.errorMessage = "이미 가입된 이메일입니다. 로그인 화면으로 이동해주세요."
                } else {
                    state.errorMessage = error.localizedDescription
                }
                return .none
                
            case .verifyButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [email = state.email, code = state.verificationCode] send in
                    do {
                        let response = try await verifyRequest(email, code)
                        await send(.verifyResponse(.success(response)))
                    } catch {
                        if let verifyError = error as? SignupError {
                            await send(.verifyResponse(.failure(verifyError)))
                        } else {
                            await send(.verifyResponse(.failure(.serverError(error.localizedDescription))))
                        }
                    }
                }
                
            case let .verifyResponse(.success(response)):
                state.isLoading = false
                switch response {
                case let .success(token):
                    state.isVerified = true
                    state.token = token
                    state.errorMessage = "이메일 인증이 완료되었습니다."
                    
                    return .run { [token] send in
                        do {
                            try await tokenStorage.saveToken(token)
                        } catch {
                            await send(.verifyResponse(.failure(.serverError("토큰 저장에 실패했습니다: \(error.localizedDescription)"))))
                        }
                    }
                }
                
            case let .verifyResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .setIsLoggedIn(isLoggedIn):
                state.isLoggedIn = isLoggedIn
                if isLoggedIn, let token = state.token {
                    return .run { _ in
                        try await tokenStorage.saveToken(token)
                    }
                }
                return .none
            }
        }
    }
}

// MARK: - API Response Types
private struct ErrorResponse: Decodable {
    let reason: String
    let error: Bool?
    let status: Int?
}

extension DependencyValues {
    var signupRequest: (String, String, String) async throws -> SignupFeature.SignupResponseType {
        get { self[SignupRequestKey.self] }
        set { self[SignupRequestKey.self] = newValue }
    }
    
    var verifyRequest: (String, String) async throws -> SignupFeature.VerifyResponseType {
        get { self[VerifyRequestKey.self] }
        set { self[VerifyRequestKey.self] = newValue }
    }
}

private struct SignupRequestKey: DependencyKey {
    static var liveValue: (String, String, String) async throws -> SignupFeature.SignupResponseType = { username, email, password in
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
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignupFeature.SignupError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 201:
            return .newUser
        case 200:
            return .existingUnverifiedUser
        case 500:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let errorMessage = errorResponse.reason
                if errorMessage.contains("SendGrid") {
                    throw SignupFeature.SignupError.emailServiceError
                }
                throw SignupFeature.SignupError.internalServerError(errorMessage)
            }
            throw SignupFeature.SignupError.internalServerError("알 수 없는 서버 오류가 발생했습니다.")
        default:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SignupFeature.SignupError.serverError(errorResponse.reason)
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SignupFeature.SignupError.serverError("Status code: \(httpResponse.statusCode), Message: \(errorMessage)")
            }
        }
    }
}

private struct VerifyRequestKey: DependencyKey {
    static let liveValue: (String, String) async throws -> SignupFeature.VerifyResponseType = { email, code in
        var request = URLRequest(url: URL(string: Endpoints.Auth.verify)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignupFeature.SignupError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            struct TokenResponse: Decodable {
                let token: String
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            return .success(token: tokenResponse.token)
        case 500:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let errorMessage = errorResponse.reason
                if errorMessage.contains("SendGrid") {
                    throw SignupFeature.SignupError.emailServiceError
                }
                throw SignupFeature.SignupError.internalServerError(errorMessage)
            }
            throw SignupFeature.SignupError.internalServerError("알 수 없는 서버 오류가 발생했습니다.")
        default:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SignupFeature.SignupError.serverError(errorResponse.reason)
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SignupFeature.SignupError.serverError("Status code: \(httpResponse.statusCode), Message: \(errorMessage)")
            }
        }
    }
}


