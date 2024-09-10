//
//  BeamPracApp.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

@main
struct BeamPracApp: App {
    
    let store: StoreOf<AppReducer> = Store(initialState: AppReducer.State()) {
           AppReducer()
               ._printChanges() // 필요하다면 디버깅 용도
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
