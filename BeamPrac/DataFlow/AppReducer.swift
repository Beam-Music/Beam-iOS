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
        var selectedTab: Tab = .home
        var isLoggedIn: Bool = false
    }
    
    enum Action: Equatable {
        case migration(MigrationReducer.Action)
        case tabBar(TabBarReducer.Action)
        case setDatabaseState(DatabaseState)
        case setSelectedTab(Tab)
        case setLoggedIn(Bool)
        case login(username: String, password: String)
    }
    
    enum Tab: Equatable {
        case home, player
    }
    
    // reduce 메서드를 명시적으로 구현
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
        case .migration:
            return .none
        case .tabBar:
            return .none
        case .login(let username, let password):
            return .run { send in
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 딜레이
                            
                            if username == "user" && password == "password" {
                                await send(.setLoggedIn(true))  // 로그인 성공
                }
              }
            }
        }
    }




// MigrationReducer 정의
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
