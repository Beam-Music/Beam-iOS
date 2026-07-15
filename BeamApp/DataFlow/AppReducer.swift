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
        var userProfile: UserProfile? = nil
        var lastTokenCheck: Date = Date()
    }
    
    enum Action: Equatable {
        case tabBar(TabBarReducer.Action)
        case setDatabaseState(DatabaseState)
        case setSelectedTab(Tab)
        case setLoggedIn(Bool)
        case home(HomeReducer.Action)
        case login(LoginFeature.Action)
        case signup(SignupFeature.Action)
        case fetchUserProfile
        case userProfileLoaded(UserProfile)
        case userProfileFailed(UserProfileError)
        case checkTokenValidity
        case tokenExpired
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
                    state.userProfile = nil
                    state.selectedTab = .home
                    state.tabBarState.playerState = nil
                    state.loginState.token = nil
                    state.signupState.token = nil
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
                state.selectedTab = .home
                state.lastTokenCheck = Date()
                return .merge(
                    .none,
                    .send(.fetchUserProfile)
                )
                
            case .login(.loginResponse(.failure)):
                return .none
                
            case .login(.emailChanged),
                 .login(.passwordChanged),
                 .login(.loginButtonTapped),
                 .login(.reset):
                return .none
                
            case .signup(.signupResponse(.success)):
                return .none
                
            case .signup(.verifyResponse(.success)):
                return .merge(
                    .none,
                    .send(.fetchUserProfile)
                )
                
            case .signup(.usernameChanged),
                 .signup(.emailChanged),
                 .signup(.passwordChanged),
                 .signup(.phoneChanged),
                 .signup(.verificationCodeChanged),
                 .signup(.signupButtonTapped),
                 .signup(.verifyButtonTapped),
                 .signup(.sendVerificationCodeButtonTapped),
                 .signup(.sendVerificationCodeResponse),
                 .signup(.signupResponse(.failure)),
                 .signup(.verifyResponse(.failure)),
                 .signup(.setIsLoggedIn),
                 .signup(.profileImageChanged),
                 .signup(.setVerificationModalPresented),
                 .signup(.setShouldShowLoginPrompt),
                 .signup(.reset):
                return .none
                
            case .home, .tabBar:
                return .none
                
            case .fetchUserProfile:
                print(">>> fetchUserProfile called")
                guard let token = state.loginState.token ?? state.signupState.token,
                      let userId = UserDefaults.standard.string(forKey: "userID") else {
                    print(">>> fetchUserProfile: token or userId missing")
                    return .none
                }
                print(">>> fetchUserProfile: userId = \(userId), token = \(token.prefix(10))...")
                return .run { send in
                    do {
                        let profile = try await UserProfileClient.fetchProfile(userId: userId, token: token)
                        print(">>> fetchUserProfile: profile loaded: \(profile)")
                        await send(.userProfileLoaded(profile))
                    } catch let error as UserProfileError {
                        print(">>> fetchUserProfile: UserProfileError: \(error)")
                        await send(.userProfileFailed(error))
                    } catch {
                        print(">>> fetchUserProfile: unknown error: \(error)")
                        await send(.userProfileFailed(.unknown))
                    }
                }
                
            case let .userProfileLoaded(profile):
                print(">>> userProfileLoaded: \(profile)")
                state.userProfile = profile
                return .none
                
            case .userProfileFailed:
                print(">>> userProfileFailed")
                // 에러 처리 (필요시)
                return .none
                
            case .checkTokenValidity:
                // 토큰 유효성 주기적 OK
                return .run { send in
                    // 5분마다 토큰 유효성 OK
                    try await Task.sleep(for: .seconds(300))
                    
                    if !(await tokenStorage.hasValidToken()) {
                        await send(.tokenExpired)
                    } else {
                        // 계속 OK
                        await send(.checkTokenValidity)
                    }
                }
                
            case .tokenExpired:
                print("⏰ Token has expired - auto-logout")
                state.isLoggedIn = false
                state.userProfile = nil
                return .send(.setLoggedIn(false))
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
