//
//  OnboardVoiceView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardVoiceView: View {
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundColor(.white)
            Text("당신의 감성, 목소리로 입히다")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            Text("당신만의 목소리를 AI가 분석, 새로운 음악 경험을 드려요.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("다음 →", action: onNext)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.7))
                .foregroundColor(.purple)
                .cornerRadius(12)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
    }
} 
