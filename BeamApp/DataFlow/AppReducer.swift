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
                state.selectedTab = .home
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
                 .signup(.sendVerificationCodeButtonTapped),
                 .signup(.sendVerificationCodeResponse),
                 .signup(.signupButtonTapped),
                 .signup(.verifyButtonTapped),
                 .signup(.signupResponse(.failure)),
                 .signup(.verifyResponse(.failure)),
                 .signup(.reset):
                return .none
                
             case .signup(.setIsLoggedIn(let isLoggedIn)):
                 return .none
             case .signup(.profileImageChanged):
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
            case .home(.playMusic(let result)):
                let track = PlayableTrackDTO(
                    id: UUID(),
                    title: result.title,
                    artistName: result.artist,
                    playbackUrl: nil,
                    playbackStoreID: result.id,
                    isAIGenerated: false,
                    duration: nil,
                    fileUrl: nil,
                    artworkURL: result.artworkURL
                )
                let playerState = PlayerReducer.State(
                    playlist: [track],
                    currentIndex: 0
                )
                return .send(.tabBar(.setPlayerState(playerState)))
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
