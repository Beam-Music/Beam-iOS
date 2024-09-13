//
//  TabBarView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
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
                ))
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppReducer.Tab.home)
                
                PlayerView()
                .tabItem {
                    Label("Player", systemImage: "play.circle.fill")
                    }
                .tag(AppReducer.Tab.player)
            }
        }
    }
}

