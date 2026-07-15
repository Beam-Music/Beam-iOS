//
//  SignupFeature.swift
//  BeamApp
//
//  Created by freed on 10/15/24.
//

import ComposableArchitecture
import Foundation
import UIKit

private enum SignupAuthValidation {
    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}

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
        var isVerificationModalPresented: Bool = false
        var shouldShowLoginPrompt: Bool = false
        var token: String? = nil
        var profileImage: UIImage? = nil
        var isSignupCompleted: Bool = false
        static func == (lhs: State, rhs: State) -> Bool {
            return lhs.username == rhs.username &&
                lhs.email == rhs.email &&
                lhs.password == rhs.password &&
                lhs.phone == rhs.phone &&
                lhs.verificationCode == rhs.verificationCode &&
                lhs.isLoading == rhs.isLoading &&
                lhs.isVerified == rhs.isVerified &&
                lhs.isLoggedIn == rhs.isLoggedIn &&
                lhs.errorMessage == rhs.errorMessage &&
                lhs.showVerificationSection == rhs.showVerificationSection &&
                lhs.isVerificationModalPresented == rhs.isVerificationModalPresented &&
                lhs.shouldShowLoginPrompt == rhs.shouldShowLoginPrompt &&
                lhs.token == rhs.token &&
                lhs.isSignupCompleted == rhs.isSignupCompleted
        }
    }
    
    enum Action: Equatable {
        case usernameChanged(String)
        case emailChanged(String)
        case passwordChanged(String)
        case phoneChanged(String)
        case verificationCodeChanged(String)
        case sendVerificationCodeButtonTapped
        case sendVerificationCodeResponse(Result<Void, SignupError>)
        case signupButtonTapped
        case verifyButtonTapped
        case signupResponse(Result<SignupResponseType, SignupError>)
        case verifyResponse(Result<VerifyResponseType, SignupError>)
        case setIsLoggedIn(Bool)
        case profileImageChanged(UIImage?)
        case setVerificationModalPresented(Bool)
        case setShouldShowLoginPrompt(Bool)
        case reset
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.usernameChanged(a), .usernameChanged(b)): return a == b
            case let (.emailChanged(a), .emailChanged(b)): return a == b
            case let (.passwordChanged(a), .passwordChanged(b)): return a == b
            case let (.phoneChanged(a), .phoneChanged(b)): return a == b
            case let (.verificationCodeChanged(a), .verificationCodeChanged(b)): return a == b
            case (.sendVerificationCodeButtonTapped, .sendVerificationCodeButtonTapped): return true
            case (.signupButtonTapped, .signupButtonTapped): return true
            case (.verifyButtonTapped, .verifyButtonTapped): return true
            case let (.signupResponse(a), .signupResponse(b)): return a == b
            case let (.verifyResponse(a), .verifyResponse(b)): return a == b
            case let (.setIsLoggedIn(a), .setIsLoggedIn(b)): return a == b
            case (.profileImageChanged, .profileImageChanged): return true
            case let (.setVerificationModalPresented(a), .setVerificationModalPresented(b)): return a == b
            case let (.setShouldShowLoginPrompt(a), .setShouldShowLoginPrompt(b)): return a == b
            case (.reset, .reset): return true
            case (.sendVerificationCodeResponse, .sendVerificationCodeResponse): return false
            default: return false
            }
        }
    }
    
    enum SignupResponseType: Equatable {
        case newUser(token: String?)
        case existingUnverifiedUser(token: String?)
    }
    
    enum VerifyResponseType: Equatable {
        case success(token: String)
        case emailVerifiedOnly
    }
    
    enum SignupError: Error, Equatable {
        case invalidResponse
        case invalidEmailFormat
        case emailAlreadyRegistered
        case emailAlreadyVerified
        case verificationCodeMismatch
        case verificationCodeExpired
        case tokenStorageFailed(String)
        case serverError(String)
        case internalServerError(String)
        case emailServiceError
        
        var localizedDescription: String {
            switch self {
            case .invalidResponse:
                return "The server response is invalid."
            case .invalidEmailFormat:
                return "Enter a valid email address."
            case .emailAlreadyRegistered:
                return "This email is already registered. Please go to the login screen."
            case .emailAlreadyVerified:
                return "This email is already verified. Please go to the login screen."
            case .verificationCodeMismatch:
                return "The verification code does not match."
            case .verificationCodeExpired:
                return "The verification code has expired. Please request a new one."
            case .tokenStorageFailed(let message):
                return "Failed to save token: \(message)"
            case .serverError(let message):
                return message
            case .internalServerError(let message):
                if message.contains("SendGrid") {
                    return "There is currently a temporary issue with the email service.\nPlease try again later."
                }
                return "An internal server error occurred.\nPlease try again later."
            case .emailServiceError:
                return "There is a temporary issue with the email service.\nPlease try again later."
            }
        }
    }
    
    @Dependency(\.signupRequest) var signupRequest
    @Dependency(\.verifyRequest) var verifyRequest
    @Dependency(\.tokenStorage) var tokenStorage
    @Dependency(\.sendVerificationCodeRequest) var sendVerificationCodeRequest
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .usernameChanged(username):
                state.username = username
                return .none
                
            case let .emailChanged(email):
                state.email = email
                state.errorMessage = nil
                state.shouldShowLoginPrompt = false
                return .none
                
            case let .passwordChanged(password):
                state.password = password
                state.errorMessage = nil
                return .none
                
            case let .phoneChanged(phone):
                state.phone = phone
                state.errorMessage = nil
                return .none
                
            case let .verificationCodeChanged(code):
                state.verificationCode = code
                state.isVerified = false
                state.token = nil
                state.errorMessage = nil
                return .none
                
            case .sendVerificationCodeButtonTapped:
                let trimmedEmail = SignupAuthValidation.normalizedEmail(state.email)
                guard !trimmedEmail.isEmpty else {
                    state.errorMessage = "Enter your email."
                    return .none
                }
                guard SignupAuthValidation.isValidEmail(trimmedEmail) else {
                    state.errorMessage = SignupError.invalidEmailFormat.localizedDescription
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                state.email = trimmedEmail
                let email = trimmedEmail
                return .run { send in
                    do {
                        try await sendVerificationCodeRequest(email)
                        await send(.sendVerificationCodeResponse(.success(())))
                    } catch {
                        if let signupError = error as? SignupError {
                            await send(.sendVerificationCodeResponse(.failure(signupError)))
                        } else {
                            await send(.sendVerificationCodeResponse(.failure(.serverError(error.localizedDescription))))
                        }
                    }
                }
                
            case let .sendVerificationCodeResponse(.success):
                state.isLoading = false
                state.errorMessage = "Verification email sent. Please check your inbox."
                state.showVerificationSection = true
                state.isVerificationModalPresented = true
                state.shouldShowLoginPrompt = false
                return .none
                
            case let .sendVerificationCodeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                state.isVerificationModalPresented = false
                return .none
                
            case .signupButtonTapped:
                let trimmedUsername = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = SignupAuthValidation.normalizedEmail(state.email)
                guard !trimmedUsername.isEmpty else {
                    state.errorMessage = "Enter your name."
                    return .none
                }
                guard !trimmedEmail.isEmpty, SignupAuthValidation.isValidEmail(trimmedEmail) else {
                    state.errorMessage = SignupError.invalidEmailFormat.localizedDescription
                    return .none
                }
                guard state.password.count >= 6 else {
                    state.errorMessage = "Password must be at least 6 characters."
                    return .none
                }
                guard state.isVerified else {
                    state.errorMessage = "Please verify your email first."
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                state.isSignupCompleted = false
                state.username = trimmedUsername
                state.email = trimmedEmail

                let username = trimmedUsername
                let email = trimmedEmail
                let password = state.password
                let profileImage = state.profileImage

                return .run { send in
                    do {
                        let response = try await signupRequest(username, email, password, profileImage)
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
                state.isSignupCompleted = true
                // Save token from the sign-up response when present.
                let token: String? = {
                    switch response {
                    case let .newUser(token): return token
                    case let .existingUnverifiedUser(token): return token
                    }
                }()
                if let token {
                    state.token = token
                }
                return .none
                
            case let .signupResponse(.failure(error)):
                state.isLoading = false
                state.isSignupCompleted = false
                switch error {
                case .emailAlreadyRegistered, .emailAlreadyVerified:
                    state.errorMessage = error.localizedDescription
                    state.shouldShowLoginPrompt = true
                default:
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
                    state.errorMessage = "Email verification is complete."
                    state.isVerificationModalPresented = false

                    // Parse userID from the token and save it to UserDefaults.
                    if let userId = Self.parseUserIdFromJWT(token) {
                        UserDefaults.standard.set(userId, forKey: "userID")
                        print("✅ userID saved: \(userId)")
                    } else {
                        print("❌ Failed to parse userID: token=\(token.prefix(20))...")
                    }

                    return .run { [token] send in
                        do {
                            try await tokenStorage.saveToken(token)
                            print("✅ Token saved after sign-up completion: \(token.prefix(10))...")
                            
                            // Confirm saved token.
                            if let savedToken = await tokenStorage.fetchToken() {
                                print("🔍 Saved token found: \(savedToken.prefix(10))...")
                            } else {
                                print("❌ Failed to fetch token after saving")
                            }
                            
                        } catch {
                            print("❌ Failed to save token: \(error)")
                            await send(.verifyResponse(.failure(.tokenStorageFailed(error.localizedDescription))))
                        }
                    }
                case .emailVerifiedOnly:
                    state.isVerified = true
                    state.errorMessage = "Email verified. Continue signing up."
                    state.isVerificationModalPresented = false
                    return .none
                }
                
            case let .verifyResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                state.isVerified = false
                state.token = nil
                state.isVerificationModalPresented = true
                return .none
                
            case let .setIsLoggedIn(isLoggedIn):
                state.isLoggedIn = isLoggedIn
                return .none
                
            case let .profileImageChanged(image):
                state.profileImage = image
                return .none

            case let .setVerificationModalPresented(isPresented):
                state.isVerificationModalPresented = isPresented
                return .none

            case let .setShouldShowLoginPrompt(shouldShow):
                state.shouldShowLoginPrompt = shouldShow
                return .none
                
            case .reset:
                state = State()
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

private func normalizedReason(from data: Data) -> String? {
    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
        return errorResponse.reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func mapSignupError(statusCode: Int, reason: String?) -> SignupFeature.SignupError {
    let normalized = reason?.lowercased() ?? ""

    if normalized.contains("already verified") || normalized.contains("already verified email") {
        return .emailAlreadyVerified
    }
    if normalized.contains("already") || normalized.contains("already registered email") || normalized.contains("already exists") {
        return .emailAlreadyRegistered
    }
    if normalized.contains("sendgrid") {
        return .emailServiceError
    }
    if statusCode == 500 {
        return .internalServerError(reason ?? "An unknown server error occurred.")
    }
    return .serverError(reason ?? "An unknown error occurred.")
}

private func mapVerificationError(statusCode: Int, reason: String?) -> SignupFeature.SignupError {
    let normalized = reason?.lowercased() ?? ""

    if normalized.contains("expired") || normalized.contains("expiration") {
        return .verificationCodeExpired
    }
    if normalized.contains("invalid code") || normalized.contains("invalid verification code") || normalized.contains("does not match") || normalized.contains("does not match") {
        return .verificationCodeMismatch
    }
    if normalized.contains("already verified") || normalized.contains("already verified email") {
        return .emailAlreadyVerified
    }
    if normalized.contains("sendgrid") {
        return .emailServiceError
    }
    if statusCode == 500 {
        return .internalServerError(reason ?? "An unknown server error occurred.")
    }
    return .serverError(reason ?? "Email verification failed.")
}

// MARK: - Success Response for Verification
private struct SuccessResponse: Decodable {
    let success: Bool
    let token: String?
    let reason: String?
}

extension DependencyValues {
    var signupRequest: (String, String, String, UIImage?) async throws -> SignupFeature.SignupResponseType {
        get { self[SignupRequestKey.self] }
        set { self[SignupRequestKey.self] = newValue }
    }
    
    var verifyRequest: (String, String) async throws -> SignupFeature.VerifyResponseType {
        get { self[VerifyRequestKey.self] }
        set { self[VerifyRequestKey.self] = newValue }
    }
    
    var sendVerificationCodeRequest: (String) async throws -> Void {
        get { self[SendVerificationCodeRequestKey.self] }
        set { self[SendVerificationCodeRequestKey.self] = newValue }
    }
}

private struct SignupRequestKey: DependencyKey {
    static var liveValue: (String, String, String, UIImage?) async throws -> SignupFeature.SignupResponseType = { username, email, password, profileImage in
        var request = URLRequest(url: URL(string: Endpoints.Auth.register)!)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // 텍스트 파트
        let params = [
            "username": username,
            "email": email,
            "password": password
        ]
        for (key, value) in params {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        // 이미지 파트 (선택)
        if let image = profileImage {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                print("✅ jpegData conversion succeeded. Image size: \(imageData.count / 1024) KB")
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            } else {
                print("❌ jpegData conversion failed. UIImage exists, but Data conversion failed.")
            }
        } else {
            print("❌ profileImage is nil. No image was selected.")
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignupFeature.SignupError.invalidResponse
        }
        struct RegisterResponse: Decodable {
            let token: String?
        }
        let registerResponse = try? JSONDecoder().decode(RegisterResponse.self, from: data)
        let token = registerResponse?.token
        switch httpResponse.statusCode {
        case 201:
            return .newUser(token: token)
        case 200:
            return .existingUnverifiedUser(token: token)
        default:
            throw mapSignupError(statusCode: httpResponse.statusCode, reason: normalizedReason(from: data))
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
            let result = try JSONDecoder().decode(SuccessResponse.self, from: data)
            guard result.success else {
                throw mapVerificationError(statusCode: httpResponse.statusCode, reason: result.reason)
            }
            if let token = result.token {
                return .success(token: token)
            } else {
                return .emailVerifiedOnly
            }
        default:
            throw mapVerificationError(statusCode: httpResponse.statusCode, reason: normalizedReason(from: data))
        }
    }
}

private struct SendVerificationCodeRequestKey: DependencyKey {
    static var liveValue: (String) async throws -> Void = { email in
        // 실제 서버 API에 맞게 구현 필요
        guard let url = URL(string: Endpoints.Auth.sendVerificationCode) else {
            throw SignupFeature.SignupError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignupFeature.SignupError.invalidResponse
        }
        if httpResponse.statusCode == 200 {
            return
        } else {
            throw mapSignupError(statusCode: httpResponse.statusCode, reason: normalizedReason(from: data))
        }
    }
}

extension SignupFeature {
    /// JWT 토큰에서 userId를 파싱 (payload의 "userId" 키)
    static func parseUserIdFromJWT(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }
        let payloadSegment = segments[1]
        var base64 = String(payloadSegment)
        // Base64 padding 보정
        let requiredLength = (4 * ((base64.count + 3) / 4))
        let paddingLength = requiredLength - base64.count
        if paddingLength > 0 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        guard let payloadData = Data(base64Encoded: base64) else { return nil }
        guard let payloadJson = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else { return nil }
        if let userId = payloadJson["userId"] as? String {
            return userId
        } else if let userId = payloadJson["userId"] as? Int {
            return String(userId)
        }
        return nil
    }
}
