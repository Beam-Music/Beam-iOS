//
//  RootView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: StoreOf<AppReducer>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                if viewStore.databaseState == .idle {
                    if viewStore.isLoggedIn {
                        TabBarView(store: store)
                    } else {
                        LoginView(store: store.scope(
                            state: \.loginState,
                            action: AppReducer.Action.login
                        ))                    }
                }
            }
            .animation(.default, value: viewStore.databaseState)
            .animation(.default, value: viewStore.isLoggedIn)
        }
    }
}

