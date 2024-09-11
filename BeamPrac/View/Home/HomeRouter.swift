//
//  HomeRouter.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct HomeReducer {
    @ObservableState
    struct State: Equatable {
        var route: Route?
    }

    enum Action {
        case setNavigation(Route?)
    }

    enum Route: Equatable {
        case detail
        case settings
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setNavigation(route):
                state.route = route
                return .none
            }
        }
    }
}

