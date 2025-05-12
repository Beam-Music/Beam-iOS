//
//  OnboardWelcomeVie2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI
import ComposableArchitecture

struct CircularText: View {
    let text: String
    let radius: CGFloat
    let kerning: CGFloat

    private var characters: [(offset: Int, element: Character)] {
        Array(text.enumerated())
    }

    private func angleInfo(index: Int, total: Int) -> (Angle, Angle) {
        if total > 1 {
            let angleForPosition = Angle(degrees: 180 + (Double(index) / Double(total - 1)) * 180)
            let angleForCharacterRotation = Angle(degrees: angleForPosition.degrees + 90)
            return (angleForPosition, angleForCharacterRotation)
        } else {
            return (Angle(degrees: 270), Angle(degrees: 0))
        }
    }

    var body: some View {
        ZStack {
            ForEach(characters, id: \.offset) { charInfo in
                let (angleForPosition, angleForCharacterRotation) = angleInfo(index: charInfo.offset, total: characters.count)
                Text(String(charInfo.element))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .kerning(kerning)
                    .rotationEffect(angleForCharacterRotation)
                    .offset(
                        x: cos(angleForPosition.radians) * radius,
                        y: sin(angleForPosition.radians) * radius
                    )
            }
        }
        .frame(width: radius * 2, height: 50)
        .offset(y: -radius)
    }
}

struct OnboardWelcomeView: View {
    let onNext: () -> Void
    let loginStore: StoreOf<LoginFeature>
    @State private var showLogin: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            CircularText(text: "BeamMusic", radius: 120, kerning: 12)
                .padding(.top, 250)
            Text("익숙한 멜로디, \n새로운 감성으로 다시 만나다")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 0)
            Text("내가 고른 노래, 내가 좋아하는 목소리로")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    HStack {
                        Spacer()
                        Text("가입하기 →")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.white.opacity(0.7))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onNext()
                }
                ZStack {
                    HStack {
                        Spacer()
                        Text("로그인하기 →")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.white.opacity(0.95))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    showLogin = true
                }
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
