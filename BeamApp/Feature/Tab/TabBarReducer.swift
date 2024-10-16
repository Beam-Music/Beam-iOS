//
//  TabBarReducer.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct TabBarReducer: Reducer {
    struct State: Equatable {
        var playerState = PlayerReducer.State()
        var generatorState = GeneratorReducer.State()
        var homeState = HomeReducer.State()
        var libraryState = LibraryReducer.State()
    }
    
    enum Action: Equatable {
        case player(PlayerReducer.Action)
        case generator(GeneratorReducer.Action)
        case home(HomeReducer.Action)
        case library(LibraryReducer.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.playerState, action: /Action.player) {
                    PlayerReducer()
        }
        Scope(state: \.generatorState, action: /Action.generator) {
                    GeneratorReducer()
        }
        Scope(state: \.homeState, action: /Action.home) {
                    HomeReducer()
        }
        Scope(state: \.libraryState, action: /Action.library) {
                    LibraryReducer()
        }
        Reduce { state, action in
            switch action {
            case let .home(.playlistLoaded(playlist)):
                state.playerState.playlist = playlist
                state.libraryState.playlist = playlist
                return .none
            default:
                return .none
            }
        }
    }
}
