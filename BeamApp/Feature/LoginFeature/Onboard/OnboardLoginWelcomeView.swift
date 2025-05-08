//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

//
//  OnboardWelcomeVie2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI
import ComposableArchitecture

struct OnboardWelcomeView: View {
    let onNext: () -> Void
    let loginStore: StoreOf<LoginFeature>
    @State private var showLogin: Bool = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text("Beam Music")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 60)
            Text("익숙한 멜로디, 새로운 감성으로 다시 만나다\n내가 고른 노래, 내가 좋아하는 목소리")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 16) {
                Button("가입하기 →") {
                    onNext()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.7))
                .foregroundColor(.purple)
                .cornerRadius(12)
                Button("로그인하기 →") {
                    showLogin = true
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(store: loginStore)
        }
    }
}
