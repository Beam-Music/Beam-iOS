//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

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
        VStack(spacing: 0) {
            Spacer(minLength: 150)
            Image("person_woman")
                .resizable()
                .scaledToFill()
                .frame(width: 362, height: 362)
                .clipped()
            Spacer(minLength: 32)
            Text("당신의 감성, 목소리로 입히다")
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            Text("좋아하는 노래를, 사랑하는 목소리로.\n AI가 당신의 취향을 닮은 새로운 음악을 만들어 드려\n요.")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
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
            Spacer(minLength: 24)
        }
        .ignoresSafeArea(edges: .top)
    }
}
