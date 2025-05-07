//
//  AppReducer.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import ComposableArchitecture
import Foundation

struct AppReducer: Reducer {
    struct State: Equatable {
        var databaseState: DatabaseState = .idle
        var tabBarState = TabBarReducer.State()
        var homeState = HomeReducer.State()
        var loginState = LoginFeature.State()
        var signupState: SignupFeature.State = SignupFeature.State()
        var selectedTab: Tab = .home
        var isLoggedIn: Bool = false
        var isSignedUp: Bool = false
    }
    
    enum Action: Equatable {
        case tabBar(TabBarReducer.Action)
        case setDatabaseState(DatabaseState)
        case setSelectedTab(Tab)
        case setLoggedIn(Bool)
        case home(HomeReducer.Action)
        case login(LoginFeature.Action)
        case signup(SignupFeature.Action)
    }

    enum Tab: Equatable {
        case home, library, settings
    }
    
    @Dependency(\.tokenStorage) var tokenStorage
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .setDatabaseState(let newState):
                state.databaseState = newState
                return .none

            case .setSelectedTab(let tab):
                state.selectedTab = tab
                return .none

            case .setLoggedIn(let isLoggedIn):
                state.isLoggedIn = isLoggedIn
                if !isLoggedIn {
                    return .run { _ in
                        try await tokenStorage.deleteAllTokens()
                        await AudioManager.shared.stop()
                        await AudioManager.shared.reset()
                    }
                }
                return .none
           
            case .login(.loginResponse(.success(let token))):
                state.isLoggedIn = true
                state.loginState.token = token
                return .none
                
            case .login(.loginResponse(.failure)):
                // 로그인 실패 시 isLoggedIn 상태는 변경하지 않음
                return .none
                
            case .login(.usernameChanged),
                 .login(.passwordChanged),
                 .login(.loginButtonTapped):
                // 로그인 관련 다른 액션들은 LoginFeature에서 처리
                return .none
                
            case .signup(.signupResponse(.success)):
                // 회원가입 요청 성공 시에는 isLoggedIn을 변경하지 않음
                // 이메일 인증이 완료되어야 로그인 상태가 됨
                return .none
                
            case .signup(.verifyResponse(.success(let response))):
                switch response {
                case .success:
                    state.isLoggedIn = true
                }
                return .none
                
            case .signup(.usernameChanged),
                 .signup(.emailChanged),
                 .signup(.passwordChanged),
                 .signup(.verificationCodeChanged),
                 .signup(.signupButtonTapped),
                 .signup(.verifyButtonTapped),
                 .signup(.signupResponse(.failure)),
                 .signup(.verifyResponse(.failure)):
                return .none
                
            case .signup(.setIsLoggedIn(let isLoggedIn)):
                state.isLoggedIn = isLoggedIn
                return .none
                
            // home과 tabBar 액션은 각각의 Scope에서 처리됨
            case .home, .tabBar:
                return .none
            }
        }
        Scope(state: \.tabBarState, action: /Action.tabBar) {
            TabBarReducer()
        }
        Scope(state: \.homeState, action: /Action.home) {
            HomeReducer()
        }
        Scope(state: \.loginState, action: /Action.login) {
            LoginFeature()
        }
        Scope(state: \.signupState, action: /Action.signup) {
            SignupFeature()
        }
    }
}

enum DatabaseState: Equatable {
    case idle, migrating, error
}
