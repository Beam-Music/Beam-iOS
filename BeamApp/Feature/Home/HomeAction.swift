//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

enum HomeAction: BindableAction, Equatable {
    case binding(BindingAction<HomeReducer.State>)
    case logOutButtonTapped
    case setNavigation(HomeReducer.Route?)
}


