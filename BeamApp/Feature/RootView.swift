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
    @State private var keyboardHeight: CGFloat = 0
    @Namespace private var albumArtNamespace
    
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
                    if viewStore.isLoggedIn, let playerState = viewStore.tabBarState.playerState, !isPlayerViewVisible {
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
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPlayerViewVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dragOffset)
            .task {
                // 앱 시작 시 저장된 토큰 확인 및 자동 로그인
                await checkSavedTokenAndAutoLogin(viewStore: viewStore)
                isLoading = false
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
        print("🚀 앱 시작 - 저장된 토큰 확인 중...")
        
        // 1. 토큰 존재 여부 확인
        guard let token = tokenStorage.fetchToken() else {
            print("🔴 저장된 토큰이 없음 - 로그인 화면으로 이동")
            return
        }
        
        #if DEBUG
        print("✅ 저장된 토큰 발견: \(token.prefix(10))...")
        #endif
        
        // 2. 토큰 유효성 확인
        guard tokenStorage.hasValidToken() else {
            print("⏰ 토큰이 만료됨 - 로그인 화면으로 이동")
            return
        }
        
        print("✅ 토큰이 유효함 - 자동 로그인 진행")
        
        // 3. 자동 로그인 처리
        await performAutoLogin(token: token, viewStore: viewStore)
    }
    
    private func performAutoLogin(token: String, viewStore: ViewStore<ViewState, AppReducer.Action>) async {
        do {
            // 1. UserDefaults에 userID 설정 (토큰에서 파싱)
            if let userId = SignupFeature.parseUserIdFromJWT(token) {
                UserDefaults.standard.set(userId, forKey: "userID")
                print("✅ userID 설정됨: \(userId)")
            }
            
            // 2. 로그인 상태 설정
            viewStore.send(.setLoggedIn(true))
            hasCompletedOnboarding = true
            
            // 3. 사용자 프로필 로드
            viewStore.send(.fetchUserProfile)
            
            // 4. 토큰 유효성 주기적 확인 시작
            viewStore.send(.checkTokenValidity)
            
            print("🎉 자동 로그인 성공!")
            
        } catch {
            print("❌ 자동 로그인 실패: \(error)")
            // 자동 로그인 실패 시 토큰 삭제
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
