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
    @State private var isAppleMusicPlayerVisible: Bool = false
    @State private var playerOffset: CGFloat = UIScreen.main.bounds.height
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isLoading = true
    @Dependency(\.tokenStorage) var tokenStorage
    let libraryStore = Store(initialState: LibraryReducer.State(), reducer: { LibraryReducer() })
    @State private var hasCompletedOnboarding = false
    @State private var keyboardHeight: CGFloat = 0
    @Namespace private var albumArtNamespace
    @ObservedObject private var appleMusicPlaybackState = AppleMusicPlaybackState.shared
    
    struct ViewState: Equatable {
        let isLoggedIn: Bool
        let hasAuthToken: Bool
        let tabBarState: TabBarReducer.State
        
        init(state: AppReducer.State) {
            self.isLoggedIn = state.isLoggedIn
            self.hasAuthToken = state.loginState.token != nil || state.signupState.token != nil
            self.tabBarState = state.tabBarState
        }
    }
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
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
                                if viewStore.hasAuthToken || tokenStorage.fetchToken() != nil {
                                    viewStore.send(.setLoggedIn(true))
                                }
                            }
                        )
                    }
                    
                    // MiniPlayerView: only show when not in full player
                    if viewStore.isLoggedIn,
                       appleMusicPlaybackState.currentSong != nil,
                       !isPlayerViewVisible,
                       !isAppleMusicPlayerVisible {
                        AppleMusicMiniPlayerView(isAppleMusicPlayerVisible: $isAppleMusicPlayerVisible)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 49)
                            .zIndex(1)
                    } else if viewStore.isLoggedIn, let playerState = viewStore.tabBarState.playerState, !isPlayerViewVisible {
                        MiniPlayerView(
                            store: store.scope(
                                state: { _ in playerState },
                                action: { AppReducer.Action.tabBar(.player($0)) }
                            ),
                            isPlayerViewVisible: $isPlayerViewVisible,
                            albumArtNamespace: albumArtNamespace
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 49)
                        .zIndex(1)
                    }

                    // PlayerView: only show when in full player mode
                    if isPlayerViewVisible, let playerState = viewStore.tabBarState.playerState {
                        PlayerView(
                            store: store.scope(
                                state: { _ in playerState },
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
                        .offset(y: max(dragOffset, 0)) // 드래그 다운할 때만 오프셋 적용
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

                    if isAppleMusicPlayerVisible, appleMusicPlaybackState.currentSong != nil {
                        AppleMusicFullPlayerView(
                            isPresented: $isAppleMusicPlayerVisible,
                            onPlayConvertibleSource: { track in
                                let playerState = PlayerReducer.State(playlist: [track], currentIndex: 0)
                                viewStore.send(.tabBar(.setPlayerState(playerState)))
                                isAppleMusicPlayerVisible = false
                                isPlayerViewVisible = true
                            }
                        )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .offset(y: max(dragOffset, 0))
                            .gesture(
                                DragGesture()
                                    .updating($dragOffset) { value, state, _ in
                                        state = value.translation.height
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 100 {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                                isAppleMusicPlayerVisible = false
                                            }
                                        }
                                    }
                            )
                            .zIndex(2)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPlayerViewVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isAppleMusicPlayerVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
            .task {
                // 앱 시작 시 Save된 토큰 OK 및 자동 로그인
                await checkSavedTokenAndAutoLogin(viewStore: viewStore)
                isLoading = false
            }
            .onChange(of: viewStore.isLoggedIn) { _, isLoggedIn in
                if !isLoggedIn {
                    isMiniPlayerVisible = false
                    isPlayerViewVisible = false
                    isAppleMusicPlayerVisible = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first
                else { return }
                let overlap = max(0, window.bounds.maxY - frame.minY - window.safeAreaInsets.bottom)
                keyboardHeight = overlap
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }
    
    // MARK: - Auto Login Logic
    
    private func checkSavedTokenAndAutoLogin(viewStore: ViewStore<ViewState, AppReducer.Action>) async {
        print("🚀 App started - checking saved token...")
        
        // 1. 토큰 존재 여부 OK
        guard let token = tokenStorage.fetchToken() else {
            print("🔴 No saved token - moving to login screen")
            return
        }
        
        #if DEBUG
        print("✅ Saved token found: \(token.prefix(10))...")
        #endif
        
        // 2. 토큰 유효성 OK
        guard tokenStorage.hasValidToken() else {
            print("⏰ Token has expired - moving to login screen")
            return
        }
        
        print("✅ Token is valid - proceeding with auto-login")
        
        // 3. 자동 로그인 처리
        await performAutoLogin(token: token, viewStore: viewStore)
    }
    
    private func performAutoLogin(token: String, viewStore: ViewStore<ViewState, AppReducer.Action>) async {
        do {
            // 1. UserDefaults에 userID 설정 (토큰에서 파싱)
            if let userId = SignupFeature.parseUserIdFromJWT(token) {
                UserDefaults.standard.set(userId, forKey: "userID")
                print("✅ userID set: \(userId)")
            }
            
            // 2. 로그인 상태 설정
            viewStore.send(.setLoggedIn(true))
            hasCompletedOnboarding = true
            
            // 3. 사용자 프로필 로드
            viewStore.send(.fetchUserProfile)
            
            // 4. 토큰 유효성 주기적 OK 시작
            viewStore.send(.checkTokenValidity)
            
            print("🎉 Auto-login succeeded!")
            
        } catch {
            print("❌ Auto-login failed: \(error)")
            // 자동 로그인 실패 시 토큰 Delete
            try? tokenStorage.deleteAllTokens()
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        let translation = value.translation.height
        
        if translation > threshold {
            // 아래로 드래그 - 플레이어 닫기
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isPlayerViewVisible = false
            }
        } else {
            // 위로 드래그 또는 임계값 미달 - 플레이어 열기
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isPlayerViewVisible = true
            }
        }
    }
}
