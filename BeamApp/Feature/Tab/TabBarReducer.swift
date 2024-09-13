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
