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
    @State private var playerOffset: CGFloat = UIScreen.main.bounds.height
    @GestureState private var dragOffset: CGFloat = 0
    
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
                            showFullPlayer()
                        }
                        .transition(.move(edge: .bottom))
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 180)
                        .zIndex(1)
                    }
                }
                .opacity(isPlayerViewVisible ? 0.3 : 1)
                
                if isPlayerViewVisible {
                    Color.black
                        .opacity(calculateBackgroundOpacity())
                        .ignoresSafeArea()
                        .zIndex(1)
                    
                    PlayerView(store: store.scope(
                        state: \.tabBarState.playerState,
                        action: { AppReducer.Action.tabBar(.player($0)) }
                    ), isMiniPlayerVisible: $isMiniPlayerVisible)
                    .background(Color.black)
                    .offset(y: calculatePlayerOffset())
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.height
                            }
                            .onEnded { value in
                                handleDragEnd(value)
                            }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                    .zIndex(2)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPlayerViewVisible) 
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
        }
    }
    
    private func calculatePlayerOffset() -> CGFloat {
        if isPlayerViewVisible {
            return max(0, dragOffset)
        } else {
            return UIScreen.main.bounds.height
        }
    }
    
    private func calculateBackgroundOpacity() -> Double {
        let maxDragDistance: CGFloat = 200
        let dragPercentage = min(dragOffset / maxDragDistance, 1)
        return 0.7 * (1 - Double(dragPercentage))
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if value.translation.height > threshold || value.predictedEndTranslation.height > threshold {
                hideFullPlayer()
            } else {
                showFullPlayer()
            }
        }
    }
    
    private func showFullPlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isPlayerViewVisible = true
            isMiniPlayerVisible = false
            playerOffset = 0
        }
    }
    
    private func hideFullPlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isPlayerViewVisible = false
            isMiniPlayerVisible = true
            playerOffset = UIScreen.main.bounds.height
        }
    }
}
