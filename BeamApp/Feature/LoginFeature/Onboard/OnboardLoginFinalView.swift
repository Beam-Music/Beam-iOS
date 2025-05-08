//
//  OnboardFinalView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardFinalView: View {
    let onFinish: () -> Void
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Image("onboard_final") // 실제 이미지 리소스명에 맞게 교체
                .resizable()
                .scaledToFit()
                .frame(height: 220)
            Text("오늘 하루, 내 마음 한구석을 살짝 채워줄 무언가가 있다면 충분할 텐데.")
                .font(.title2)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("시작하기 →", action: onFinish)
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
