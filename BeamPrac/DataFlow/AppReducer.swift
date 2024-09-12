//
//  AppReducer.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import ComposableArchitecture

struct AppReducer: Reducer {
    struct State: Equatable {
        var databaseState: DatabaseState = .idle
        var migrationState = MigrationReducer.State()
        var tabBarState = TabBarReducer.State()
        var homeState = HomeReducer.State()
        var selectedTab: Tab = .home
        var isLoggedIn: Bool = false
    }
    
    enum Action: Equatable {
        case migration(MigrationReducer.Action)
        case tabBar(TabBarReducer.Action)
        case setDatabaseState(DatabaseState)
        case setSelectedTab(Tab)
        case setLoggedIn(Bool)
        case home(HomeAction)
        case login(username: String, password: String)
    }
    
    enum Tab: Equatable {
        case home, player
    }
    
    @Dependency(\.authService) var authService  // 의존성 주입
    private enum CancelID { case login }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .setDatabaseState(let newState):
            state.databaseState = newState
            return .none

        case .setSelectedTab(let tab):
            state.selectedTab = tab
            return .none

        case .setLoggedIn(let isLoggedIn):
            state.isLoggedIn = isLoggedIn
            return .none

        case .home(let homeAction):
            switch homeAction {
        case .logOutButtonTapped:
            state.isLoggedIn = false
            return .none
        default:
            return .none
            }

            
        case .migration:
            return .none

        case .tabBar:
            return .none

        case .login(let username, let password):
            return .run { send in
                let isSuccess = try await authService.login(username, password)
                await send(.setLoggedIn(isSuccess))
            }
            .cancellable(id: CancelID.login, cancelInFlight: true)
            
        }
    }
    var body: some ReducerOf<Self> {
            Scope(state: \.homeState, action: /Action.home) {
                //todo: 필요한지 체크
//                HomeReducer()
            }
            Scope(state: \.tabBarState, action: /Action.tabBar) {
                TabBarReducer()  // TabBarReducer와 Scope로 연결
            }
        }
}

// MigrationReducer 정의
// todo: migrationView필요한지 체크
struct MigrationReducer: Reducer {
    struct State: Equatable {
        var progress: Double = 0
    }
    
    enum Action: Equatable {
        case updateProgress(Double)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .updateProgress(progress):
            state.progress = progress
            return .none
        }
    }
}

// TabBarReducer 정의
// todo : tabbarreducer, action 이동
struct TabBarReducer: Reducer {
    struct State: Equatable {
        var playerState = PlayerReducer.State()
        var generatorState = GeneratorReducer.State()
    }
    
    enum Action: Equatable {
        case player(PlayerReducer.Action)
        case generator(GeneratorReducer.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.playerState, action: /Action.player) {
            PlayerReducer()
        }
        Scope(state: \.generatorState, action: /Action.generator) {
            GeneratorReducer()
        }
    }
}

// PlayerReducer 정의
struct PlayerReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}

// GeneratorReducer 정의
struct GeneratorReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}
