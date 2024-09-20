//
//  AuthClient.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct AuthClient {
    var login: (String, String) async throws -> Bool
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        login: { username, password in
            try await Task.sleep(for: .seconds(1))
            return username == "user" && password == "password"
        }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

