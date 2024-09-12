//
//  LoginAction.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

enum LoginAction: BindableAction {
    case binding(BindingAction<LoginReducer.State>)  // 바인딩 액션
    case loginButtonTapped  // 로그인 버튼 클릭 시 액션
    case loginResponse(TaskResult<Bool>)  // 비동기 로그인 응답
    case setNavigation(LoginReducer.Route?)  // 네비게이션 설정
    case loginSuccess  // 로그인 성공 시 액션
}

