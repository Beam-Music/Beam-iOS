//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

//
//  OnboardVisionView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardVisionView: View {
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("onboard_vision") // 실제 이미지 리소스명에 맞게 교체
                .resizable()
                .scaledToFit()
                .frame(height: 220)
            Text("BEAM의 비전과 가치")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            Text("빔뮤직은 AI와 음악의 만남을 통해, 사용자에게 새로운 음악 경험을 선사합니다. 음악, 목소리, 감정 표현의 새로운 가능성을 경험해보세요.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("시작하기 →", action: onNext)
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
