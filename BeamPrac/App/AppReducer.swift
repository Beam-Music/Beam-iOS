//
//  AppReducer.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
    struct State: Equatable {
        var migrationState = MigrationReducer.State()
        var tabBarState = TabBarReducer.State()
        var databaseState: DatabaseState = .idle
    }
    
    enum Action: Equatable {
        case migration(MigrationReducer.Action)
        case tabBar(TabBarReducer.Action)
        case setDatabaseState(DatabaseState)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .setDatabaseState(let newState):
                state.databaseState = newState
                return .none
            case .migration, .tabBar:
                return .none
            }
        }
        Scope(state: \.migrationState, action: /Action.migration) {
            MigrationReducer()
        }
        Scope(state: \.tabBarState, action: /Action.tabBar) {
            TabBarReducer()
        }
    }
}

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

enum DatabaseState: Equatable {
    case idle, migrating, error
}

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

// Note: PlayerReducer and GeneratorReducer are not defined here.
// You should create separate files for these reducers.

