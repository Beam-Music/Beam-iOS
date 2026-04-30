//
//  AuthService.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture
import Foundation
import Combine

struct AuthService {
    var login: @Sendable (String, String) async throws -> String
}

extension AuthService: DependencyKey {
    static let liveValue: Self = {
        AuthService(
            login: { username, password in
            guard let url = URL(string: Endpoints.Auth.login) else {
                throw LoginError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["email": username, "password": password]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LoginError.invalidResponse
            }
            if httpResponse.statusCode == 401 {
                // 서버의 reason 메시지 파싱
                struct ErrorResponse: Decodable { let reason: String }
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                   errorResponse.reason.lowercased().contains("verify your email") {
                    throw LoginError.emailNotVerified
                } else {
                    throw LoginError.invalidCredentials
                }
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw LoginError.invalidResponse
            }
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 Login Response: \(responseString)")
            }
            #endif
            struct TokenResponse: Decodable {
                let accessToken: String
                let refreshToken: String
                let expiresIn: Int
                let tokenType: String
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            @Dependency(\.tokenStorage) var tokenStorage
            do {
                try await tokenStorage.saveToken(tokenResponse.accessToken)
                #if DEBUG
                print("✅ 토큰이 성공적으로 저장됨: \(tokenResponse.accessToken.prefix(10))...")

                if let savedToken = await tokenStorage.fetchToken() {
                    print("🔍 저장된 토큰 확인: \(savedToken.prefix(10))...")
                } else {
                    print("❌ 토큰 저장 후 검색 실패")
                }
                #endif

            } catch {
                print("❌ 토큰 저장 실패: \(error)")
                throw error
            }
            return tokenResponse.accessToken
        }
        )
    }()
}

enum LoginError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case invalidCredentials
    case emailNotVerified
    case serverError
    case decodingError(DecodingError)
    case networkError(Error)
    case unknownError
    
    static func == (lhs: LoginError, rhs: LoginError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
            (.invalidResponse, .invalidResponse),
            (.invalidCredentials, .invalidCredentials),
            (.serverError, .serverError),
            (.unknownError, .unknownError):
            return true
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthService.self] }
        set { self[AuthService.self] = newValue }
    }
}

