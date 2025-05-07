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
    @Binding var isMiniPlayerVisible: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(
                get: \.selectedTab,
                send: AppReducer.Action.setSelectedTab
            )) {
                HomeView(isLoggedIn: viewStore.binding(
                    get: \.isLoggedIn,
                    send: { .setLoggedIn($0) }
                ), isMiniPlayerVisible: $isMiniPlayerVisible,
                         store: store.scope(
                            state: \.tabBarState.homeState,
                            action: { AppReducer.Action.tabBar(.home($0)) }
                         ))
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(AppReducer.Tab.home)
                
                LibraryView(store: store.scope(
                    state: \.tabBarState.libraryState,
                    action: { AppReducer.Action.tabBar(.library($0)) }
                ),
                            isMiniPlayerVisible: $isMiniPlayerVisible)
                .tabItem {
                    Label("플레이리스트", systemImage: "music.note.list")
                }
                .tag(AppReducer.Tab.library)

                SettingsView(isLoggedIn: viewStore.binding(
                    get: \.isLoggedIn,
                    send: { .setLoggedIn($0) }
                ))
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(AppReducer.Tab.settings)
            }
            .accentColor(Color.purple)
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
    }
}
