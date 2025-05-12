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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Image("person_man")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 600)
                    .clipped()
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 12) {
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
                }
                .padding(.bottom, 100)
                Spacer()
            }
            ZStack {
                HStack {
                    Spacer()
                    Text("다음 →")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.white.opacity(0.7))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                onNext()
            }
        }
        .padding(.top, 0)
        .ignoresSafeArea(edges: .top)
    }
}
