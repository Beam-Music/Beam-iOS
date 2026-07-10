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
    @State private var isOnboardingCompleted: Bool = false
    @State private var isPaging: Bool = false
    
    var body: some View {
        ZStack {
            AppTheme.onboardingGradient
            .edgesIgnoringSafeArea(.all)
            
            TabView(selection: $page) {
                OnboardWelcomeView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                }, loginStore: loginStore)
                    .tag(0)
                
                OnboardSignupView(store: signupStore, loginStore: loginStore, onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(1)
                
                OnboardVisionView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(2)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardEmotionView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(3)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardMusicView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(4)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardVoiceView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(5)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardTasteView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(6)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardLoginDoneSignupView(onNext: {
                    if !isOnboardingCompleted && !isPaging {
                        isPaging = true
                        page += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isPaging = false }
                    }
                })
                    .tag(7)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardFinalView(onFinish: {
                    isOnboardingCompleted = true
                    onOnboardingFinished()
                })
                    .tag(8)
                    .edgesIgnoringSafeArea(.all)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)
            .edgesIgnoringSafeArea(.all)
            .gesture(
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: page) { newPage in
            if isOnboardingCompleted && newPage < 8 {
                page = 8
            }
        }
    }
}
