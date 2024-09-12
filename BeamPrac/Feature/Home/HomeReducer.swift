//
//  HomeRouter.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import ComposableArchitecture

@Reducer
struct HomeReducer {
    struct State: Equatable {
        var route: Route?  // 네비게이션 상태
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case logOutButtonTapped  // 로그아웃 버튼 클릭 시 액션
        case setNavigation(Route?)
    }

    enum Route: Equatable {
        case detail
        case settings
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .logOutButtonTapped:
                return .none

            case let .setNavigation(route):
                state.route = route
                return .none
            }
        }
    }
}
