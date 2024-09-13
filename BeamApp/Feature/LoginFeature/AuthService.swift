//
//  AuthService.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct AuthService {
    var login: (String, String) async throws -> Bool
}

extension AuthService: DependencyKey {
    static var liveValue: AuthService {
        AuthService { username, password in
            // 실제 로그인 로직
            return username == "user" && password == "password"
        }
    }
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthService.self] }
        set { self[AuthService.self] = newValue }
    }
}

