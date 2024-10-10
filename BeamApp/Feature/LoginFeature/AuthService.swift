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
    static var liveValue: AuthService {
        AuthService { username, password in
            guard let url = URL(string: Endpoints.Auth.login) else {
                throw LoginError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["username": username, "password": password]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw LoginError.invalidResponse
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            @Dependency(\.tokenStorage) var tokenStorage
            do {
                try await tokenStorage.saveToken(tokenResponse.token)
                print("토큰 저장 성공:")
            } catch {
                print("토큰 저장 실패: \(error)")
            }
            return tokenResponse.token
        }
    }
}

enum LoginError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case invalidCredentials
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

struct TokenResponse: Decodable {
    let token: String
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthService.self] }
        set { self[AuthService.self] = newValue }
    }
}

