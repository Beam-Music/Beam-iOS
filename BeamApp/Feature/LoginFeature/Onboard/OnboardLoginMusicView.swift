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
        VStack(spacing: 0) {
            Image("onboard_music")
                .resizable()
                .scaledToFill()
                .frame(height: 600)
                .clipped()
            Spacer(minLength: 12)
            Text("음악을 당신답게")
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            Text("원하는 곡, 선호하는 목소리,\n당신만의 조합으로 완성되는 음악 경험을 만나보세요.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            Spacer()
            Button("다음 →", action: onNext)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.7))
                .foregroundColor(.purple)
                .cornerRadius(12)
                .padding(.horizontal, 32)
            Spacer(minLength: 24)
        }
        .padding(.top, 0)
        .ignoresSafeArea(edges: .top)
    }
}
