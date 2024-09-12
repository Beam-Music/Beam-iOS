//
//  LoginRouter.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import ComposableArchitecture

@Reducer
struct LoginReducer {
    @ObservableState
    struct State: Equatable {
        var username = ""
        var password = ""
        var isLoading = false
        var errorMessage: String?
        var route: Route?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loginButtonTapped
        case loginResponse(TaskResult<Bool>)
        case setNavigation(Route?)
        case loginSuccess
    }

    enum Route: Equatable {
        case forgotPassword
        case registration
    }

    @Dependency(\.authClient) var authClient

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .loginButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                return .run { [username = state.username, password = state.password] send in
                    await send(.loginResponse(TaskResult { try await authClient.login(username, password) }))
                }
                
            case .loginResponse(.success):
                state.isLoading = false
                return .send(.loginSuccess)
                
            case let .loginResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .setNavigation(route):
                state.route = route
                return .none
                
            case .loginSuccess:
                return .none
            }
        }
    }
}

