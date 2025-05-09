//  OnboardVoiceView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardVoiceView: View {
    let onNext: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Image("person_woman")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 600)
                    .clipped()
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 12) {
                    Text("당신의 감성, 목소리로 입히다")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                    Text("좋아하는 노래를, 사랑하는 목소리로.\nAI가 당신의 취향을 닮은 새로운 음악을 만들어 드려요.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                }
                .padding(.bottom, 100)
                Spacer()
            }
            Button("다음 →", action: onNext)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.7))
                .foregroundColor(.purple)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .padding(.top, 0)
        .ignoresSafeArea(edges: .top)
    }
}
