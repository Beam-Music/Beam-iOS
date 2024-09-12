//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct PlayerReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}

struct GeneratorReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}
