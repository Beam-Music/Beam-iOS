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
    @State private var isLoading = true
    @Dependency(\.tokenStorage) var tokenStorage
    let libraryStore = Store(initialState: LibraryReducer.State(), reducer: { LibraryReducer() })
    @State private var hasCompletedOnboarding = false
    @Namespace private var albumArtNamespace
    
    struct ViewState: Equatable {
        let isLoggedIn: Bool
        
        init(state: AppReducer.State) {
            self.isLoggedIn = state.isLoggedIn
        }
    }
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(Color.purple)
                } else {
                    if viewStore.isLoggedIn {
                        TabBarView(store: store, libraryStore: libraryStore, isMiniPlayerVisible: $isMiniPlayerVisible)
                        .zIndex(0)
                    } else {
                        OnboardView(
                            loginStore: store.scope(
                                state: \.loginState,
                                action: AppReducer.Action.login
                            ),
                            signupStore: store.scope(
                                state: \.signupState,
                                action: AppReducer.Action.signup
                            ),
                            onOnboardingFinished: {
                                hasCompletedOnboarding = true
                                viewStore.send(.setSelectedTab(.home))
                                viewStore.send(.setLoggedIn(true))
                            }
                        )
                    }
                    
                    // MiniPlayerView: only show when not in full player
                    if let _ = viewStore.tabBarState.playerState, !isPlayerViewVisible {
                        VStack {
                            Spacer()
                            MiniPlayerView(
                                store: store.scope(
                                    state: \ .tabBarState.playerState!,
                                    action: { AppReducer.Action.tabBar(.player($0)) }
                                ),
                                isPlayerViewVisible: $isPlayerViewVisible,
                                albumArtNamespace: albumArtNamespace
                            )
                            .onTapGesture {
                                showFullPlayer()
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .padding(.bottom, 85)
                        }
                        .ignoresSafeArea(edges: .bottom)
                    }

                    // PlayerView: only show when in full player mode
                    if isPlayerViewVisible, let _ = viewStore.tabBarState.playerState {
                        PlayerView(
                            store: store.scope(
                                state: \ .tabBarState.playerState!,
                                action: { AppReducer.Action.tabBar(.player($0)) }
                            ),
                            isMiniPlayerVisible: $isMiniPlayerVisible,
                            libraryStore: libraryStore,
                            albumArtNamespace: albumArtNamespace
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
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
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPlayerViewVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
            .task {
                // Check for saved token on app launch
                if let token = tokenStorage.fetchToken() {
                    hasCompletedOnboarding = true
                    viewStore.send(.setLoggedIn(true))
                }
                isLoading = false
            }
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
