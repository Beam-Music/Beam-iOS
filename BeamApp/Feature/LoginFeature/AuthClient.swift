//
//  AuthClient.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

// AuthClient 정의
struct AuthClient {
    var login: (String, String) async throws -> Bool
}

// AuthClient가 DependencyKey를 채택
extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        login: { username, password in
            // 실제 로그인 처리 로직
            try await Task.sleep(for: .seconds(1))  // 1초 지연 (모의 네트워크)
            return username == "user" && password == "password"
        }
    )
}

// DependencyValues에 authClient 추가
extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

