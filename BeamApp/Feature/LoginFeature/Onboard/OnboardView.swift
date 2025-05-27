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
    let totalPages = 8
    let loginStore: StoreOf<LoginFeature>
    let signupStore: StoreOf<SignupFeature>
    let onOnboardingFinished: () -> Void
    @State private var navigateToLogin: Bool = false
    @State private var navigateToSignup: Bool = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.7), Color.orange.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            TabView(selection: $page) {
                OnboardWelcomeView(onNext: { page += 1 }, loginStore: loginStore)
                    .tag(0)
                
                OnboardSignupView(store: signupStore, onNext: { page += 1 })
                    .tag(1)
                
                OnboardVisionView(onNext: { page += 1 })
                    .tag(2)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardEmotionView(onNext: { page += 1 })
                    .tag(3)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardMusicView(onNext: { page += 1 })
                    .tag(4)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardVoiceView(onNext: { page += 1 })
                    .tag(5)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardTasteView(onNext: { page += 1 })
                    .tag(6)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardLoginDoneSignupView(onNext: { page += 1 })
                    .tag(7)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardFinalView(onFinish: { onOnboardingFinished() })
                    .tag(8)
                    .edgesIgnoringSafeArea(.all)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)
            .edgesIgnoringSafeArea(.all)
            .highPriorityGesture(DragGesture())
        }
        .edgesIgnoringSafeArea(.all) // Apply to root view
    }
}
