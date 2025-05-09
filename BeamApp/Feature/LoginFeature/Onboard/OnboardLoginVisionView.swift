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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Image("onboard_vision")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 600)
                    .clipped()
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 12) {
                    Text("BEAM의 비전과 가치")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                    Text("빔뮤직은 AI와 음악의 만남을 통해, 사용자에게 새로운 음악 경험을 선사합니다. 음악, 목소리, 감정 표현의 새로운 가능성을 경험해보세요.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                }
                .padding(.bottom, 100)
                Spacer()
            }
            Button("시작하기 →", action: onNext)
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
