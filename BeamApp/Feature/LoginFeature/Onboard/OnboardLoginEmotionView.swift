//
//  OnboardEmotionView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardEmotionView: View {
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "person")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundColor(.white)
            Text("감성의 스펙트럼을 넘히다")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            Text("익숙한 멜로디, AI가 만들어내는 감정의 스펙트럼. 지금 경험해보세요.")
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
