//
//  LoginAction.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

enum LoginAction: BindableAction {
    case binding(BindingAction<LoginReducer.State>)
    case loginButtonTapped
    case loginResponse(TaskResult<Bool>)
    case setNavigation(LoginReducer.Route?)
    case loginSuccess
}

