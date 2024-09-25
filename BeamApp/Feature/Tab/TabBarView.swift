//
//  TabBarView.swift
//  BeamApp
//
//  Created by freed on 9/13/24.
//

import SwiftUI
import ComposableArchitecture

struct TabBarView: View {
    let store: StoreOf<AppReducer>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(
                get: \.selectedTab,
                send: AppReducer.Action.setSelectedTab
            )) {
                HomeView(isLoggedIn: viewStore.binding(
                    get: \.isLoggedIn,
                    send: { .setLoggedIn($0) }
                ),
                         store: store.scope(
                            state: \.homeState,
                            action: AppReducer.Action.home
                         )
                )
                
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppReducer.Tab.home)
                
                PlayerView(store: store.scope(
                    state: \.homeState,
                    action: AppReducer.Action.home
                ))
                .tabItem {
                    Label("Player", systemImage: "play.circle.fill")
                    }
                .tag(AppReducer.Tab.player)
            }
        }
    }
}
