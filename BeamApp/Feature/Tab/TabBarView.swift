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
    
    //    var body: some View {
    //        WithViewStore(store, observe: { $0 }) { viewStore in
    //            TabView(selection: viewStore.binding(
    //                get: \.selectedTab,
    //                send: AppReducer.Action.setSelectedTab
    //            )) {
    //                HomeView(isLoggedIn: viewStore.binding(
    //                    get: \.isLoggedIn,
    //                    send: { .setLoggedIn($0) }
    //                ), isMiniPlayerVisible: $isMiniPlayerVisible,
    //                         store: store.scope(
    //                            state: \.tabBarState.homeState,
    //                            action: { AppReducer.Action.tabBar(.home($0)) }
    //                         ))
    //                .tabItem {
    //                    Label("Home", systemImage: "house.fill")
    //                }
    //                .tag(AppReducer.Tab.home)
    //
    //                LibraryView(store: store.scope(
    //                    state: \.tabBarState.libraryState,
    //                    action: { AppReducer.Action.tabBar(.library($0)) }
    //                ),
    //                            isMiniPlayerVisible: $isMiniPlayerVisible)
    //                .tabItem {
    //                    Label("Library", systemImage: "books.vertical.fill")
    //                }
    //                .tag(AppReducer.Tab.library)
    //            }
    //            .accentColor(.white)
    //        }
    //    }
    var body: some View {
        NavigationView {
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
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(AppReducer.Tab.home)
                    
                    LibraryView(store: store.scope(
                        state: \.tabBarState.libraryState,
                        action: { AppReducer.Action.tabBar(.library($0)) }
                    ),
                                isMiniPlayerVisible: $isMiniPlayerVisible)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical.fill")
                    }
                    .tag(AppReducer.Tab.library)
                }
                .accentColor(.white)
            }
        }
        
    }
}
