//
//  SignupFeature.swift
//  BeamApp
//
//  Created by freed on 10/15/24.
//

import ComposableArchitecture
import Foundation
import UIKit

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
                return "서버 응답이 올바르지 않습니다."
            case .invalidEmailFormat:
                return "올바른 이메일 형식을 입력해 주세요."
            case .emailAlreadyRegistered:
                return "이미 가입된 이메일입니다. 로그인 화면으로 이동해주세요."
            case .emailAlreadyVerified:
                return "이미 인증된 이메일입니다. 로그인 화면으로 이동해주세요."
            case .verificationCodeMismatch:
                return "인증 번호가 일치하지 않습니다."
            case .verificationCodeExpired:
                return "인증 코드가 만료되었습니다. 다시 요청해 주세요."
            case .tokenStorageFailed(let message):
                return "토큰 저장에 실패했습니다: \(message)"
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
                let trimmedEmail = AuthValidation.normalizedEmail(state.email)
                guard !trimmedEmail.isEmpty else {
                    state.errorMessage = "이메일을 입력해 주세요."
                    return .none
                }
                guard AuthValidation.isValidEmail(trimmedEmail) else {
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
                state.errorMessage = "인증 메일이 발송되었습니다. 이메일을 확인해주세요."
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
                let trimmedEmail = AuthValidation.normalizedEmail(state.email)
                guard !trimmedUsername.isEmpty else {
                    state.errorMessage = "이름을 입력해 주세요."
                    return .none
                }
                guard !trimmedEmail.isEmpty, AuthValidation.isValidEmail(trimmedEmail) else {
                    state.errorMessage = SignupError.invalidEmailFormat.localizedDescription
                    return .none
                }
                guard state.password.count >= 6 else {
                    state.errorMessage = "비밀번호는 6자 이상 입력해 주세요."
                    return .none
                }
                guard state.isVerified else {
                    state.errorMessage = "이메일 인증을 먼저 완료해 주세요."
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
                // 회원가입 응답에서 토큰이 있으면 저장
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
                    state.errorMessage = "이메일 인증이 완료되었습니다."
                    state.isVerificationModalPresented = false

                    // userID를 토큰에서 파싱하여 UserDefaults에 저장
                    if let userId = Self.parseUserIdFromJWT(token) {
                        UserDefaults.standard.set(userId, forKey: "userID")
                        print("✅ userID 저장됨: \(userId)")
                    } else {
                        print("❌ userID 파싱 실패: token=\(token.prefix(20))...")
                    }

                    return .run { [token] send in
                        do {
                            try await tokenStorage.saveToken(token)
                            print("✅ 회원가입 완료 후 토큰 저장 성공: \(token.prefix(10))...")
                            
                            // 토큰 저장 확인
                            if let savedToken = await tokenStorage.fetchToken() {
                                print("🔍 저장된 토큰 확인: \(savedToken.prefix(10))...")
                            } else {
                                print("❌ 토큰 저장 후 검색 실패")
                            }
                            
                        } catch {
                            print("❌ 토큰 저장 실패: \(error)")
                            await send(.verifyResponse(.failure(.tokenStorageFailed(error.localizedDescription))))
                        }
                    }
                case .emailVerifiedOnly:
                    state.isVerified = true
                    state.errorMessage = "이메일 인증 성공! 회원가입을 진행하세요."
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

    if normalized.contains("already verified") || normalized.contains("이미 인증된 이메일") {
        return .emailAlreadyVerified
    }
    if normalized.contains("already") || normalized.contains("이미 가입된 이메일") || normalized.contains("already exists") {
        return .emailAlreadyRegistered
    }
    if normalized.contains("sendgrid") {
        return .emailServiceError
    }
    if statusCode == 500 {
        return .internalServerError(reason ?? "알 수 없는 서버 오류가 발생했습니다.")
    }
    return .serverError(reason ?? "알 수 없는 오류가 발생했습니다.")
}

private func mapVerificationError(statusCode: Int, reason: String?) -> SignupFeature.SignupError {
    let normalized = reason?.lowercased() ?? ""

    if normalized.contains("expired") || normalized.contains("만료") {
        return .verificationCodeExpired
    }
    if normalized.contains("invalid code") || normalized.contains("invalid verification code") || normalized.contains("does not match") || normalized.contains("일치하지") {
        return .verificationCodeMismatch
    }
    if normalized.contains("already verified") || normalized.contains("이미 인증된 이메일") {
        return .emailAlreadyVerified
    }
    if normalized.contains("sendgrid") {
        return .emailServiceError
    }
    if statusCode == 500 {
        return .internalServerError(reason ?? "알 수 없는 서버 오류가 발생했습니다.")
    }
    return .serverError(reason ?? "이메일 인증에 실패했습니다.")
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
                print("✅ jpegData 변환 성공! 이미지 크기: \(imageData.count / 1024) KB")
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            } else {
                print("❌ jpegData 변환 실패! (UIImage는 있으나 Data 변환 실패)")
            }
        } else {
            print("❌ profileImage가 nil입니다. (이미지 선택 안 됨)")
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


