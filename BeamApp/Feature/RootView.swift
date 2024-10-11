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
    @State private var isMiniPlayerVisible: Bool = true
    @State private var isPlayerViewVisible: Bool = false
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                ZStack {
                    if viewStore.databaseState == .idle {
                        if viewStore.isLoggedIn {
                            TabBarView(store: store, isMiniPlayerVisible: $isMiniPlayerVisible)
                                .zIndex(0)
                        } else {
                            LoginView(store: store.scope(
                                state: \.loginState,
                                action: AppReducer.Action.login
                            ))
                        }
                    }
                    
                    if isMiniPlayerVisible && !isPlayerViewVisible && viewStore.isLoggedIn {
                        MiniPlayerView(store: store.scope(
                            state: \.tabBarState.playerState,
                            action: { AppReducer.Action.tabBar(.player($0)) }
                        ), isPlayerViewVisible: $isPlayerViewVisible)
                        .onTapGesture {
                            withAnimation {
                                isPlayerViewVisible = true
                                isMiniPlayerVisible = false
                            }
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: isMiniPlayerVisible)
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 180)
                        .zIndex(1)
                    }
                }
                
                if isPlayerViewVisible {
                    Color.black.edgesIgnoringSafeArea(.all)
                    PlayerView(store: store.scope(
                        state: \.tabBarState.playerState,
                        action: { AppReducer.Action.tabBar(.player($0)) }
                    ), isMiniPlayerVisible: $isMiniPlayerVisible)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut)
                    .onTapGesture {
                        withAnimation {
                            isPlayerViewVisible = false
                            isMiniPlayerVisible = true
                        }
                    }
                    .gesture(DragGesture().onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation {
                                isPlayerViewVisible = false
                                isMiniPlayerVisible = true
                            }
                        }
                    })
                    .ignoresSafeArea()
                    .zIndex(2)
                }
            }
            .animation(.default, value: viewStore.databaseState)
            .animation(.default, value: viewStore.isLoggedIn)
        }
    }
}
