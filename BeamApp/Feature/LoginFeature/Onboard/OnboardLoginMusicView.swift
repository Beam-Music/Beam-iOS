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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Image("onboard_music")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 600)
                    .clipped()
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 12) {
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
                .padding() 
                .background(Color.white.opacity(0.7))
                .cornerRadius(12) 
            }
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
