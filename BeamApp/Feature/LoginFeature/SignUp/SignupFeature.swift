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
        var token: String? = nil
        var profileImage: UIImage? = nil
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
                lhs.token == rhs.token
        }
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
        case profileImageChanged(UIImage?)
        case reset
        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.usernameChanged(a), .usernameChanged(b)): return a == b
            case let (.emailChanged(a), .emailChanged(b)): return a == b
            case let (.passwordChanged(a), .passwordChanged(b)): return a == b
            case let (.phoneChanged(a), .phoneChanged(b)): return a == b
            case let (.verificationCodeChanged(a), .verificationCodeChanged(b)): return a == b
            case (.signupButtonTapped, .signupButtonTapped): return true
            case (.verifyButtonTapped, .verifyButtonTapped): return true
            case let (.signupResponse(a), .signupResponse(b)): return a == b
            case let (.verifyResponse(a), .verifyResponse(b)): return a == b
            case let (.setIsLoggedIn(a), .setIsLoggedIn(b)): return a == b
            case (.profileImageChanged, .profileImageChanged): return true
            case (.reset, .reset): return true
            default: return false
            }
        }
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

                let username = state.username
                let email = state.email
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
                
            case let .profileImageChanged(image):
                state.profileImage = image
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

extension DependencyValues {
    var signupRequest: (String, String, String, UIImage?) async throws -> SignupFeature.SignupResponseType {
        get { self[SignupRequestKey.self] }
        set { self[SignupRequestKey.self] = newValue }
    }
    
    var verifyRequest: (String, String) async throws -> SignupFeature.VerifyResponseType {
        get { self[VerifyRequestKey.self] }
        set { self[VerifyRequestKey.self] = newValue }
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


