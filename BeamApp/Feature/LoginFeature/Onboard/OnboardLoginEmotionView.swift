//
//  OnboardLoginEmotionView.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

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
        VStack(spacing: 0) {
            Spacer(minLength: 150)
            Image("person_man")
                .resizable()
                .scaledToFill()
                .frame(width: 380, height: 380)
                .clipped()
            Spacer(minLength: 10)
            Text("감성의 스펙트럼을 넓히다")
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            Text("익숙한 곡도, 새로운 감동으로.\nAI가 전하는 '취향의 재해석'을 지금 경험해보세요.")
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
