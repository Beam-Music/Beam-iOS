//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

enum HomeAction: BindableAction, Equatable {
    case binding(BindingAction<HomeReducer.State>)  // 바인딩 액션
    case logOutButtonTapped  // 로그아웃 버튼 클릭 시 액션
    case setNavigation(HomeReducer.Route?)  // 네비게이션 변경
}


