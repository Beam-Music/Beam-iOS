//
//  OnboardView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct OnboardView: View {
    @State private var page: Int = 0
    let totalPages = 8 // 실제 화면 개수에 맞게 조정
    let loginStore: StoreOf<LoginFeature>
    let signupStore: StoreOf<SignupFeature>
    let onOnboardingFinished: () -> Void // 홈 전환용 클로저
    @State private var navigateToLogin: Bool = false
    @State private var navigateToSignup: Bool = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.7), Color.orange.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            TabView(selection: $page) {
                OnboardWelcomeView(onNext: { page += 1 }, loginStore: loginStore).tag(0)
                OnboardSignupView(store: signupStore, onNext: { page += 1 }).tag(1)
                OnboardVisionView(onNext: { page += 1 }).tag(2)
                OnboardEmotionView(onNext: { page += 1 }).tag(3)
                OnboardMusicView(onNext: { page += 1 }).tag(4)
                OnboardVoiceView(onNext: { page += 1 }).tag(5)
                OnboardTasteView(onNext: { page += 1 }).tag(6)
                OnboardKeywordView(onNext: { page += 1 }).tag(7)
                OnboardFinalView(onFinish: { onOnboardingFinished() }).tag(8)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)
        }
    }
}
