//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

import SwiftUI

struct OnboardMusicView: View {
    let onNext: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("onboard_music") // 실제 이미지 리소스명에 맞게 교체
                .resizable()
                .scaledToFit()
                .frame(height: 180)
            Text("음악을 당신답게")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            Text("당신만의 감정과 음악, AI가 당신만을 위한 음악을 만나보세요.")
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
