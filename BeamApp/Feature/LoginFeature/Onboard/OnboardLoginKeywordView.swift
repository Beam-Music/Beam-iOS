//
//  OnboardKeywordView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardKeywordView: View {
    let onNext: () -> Void
    @State private var selectedKeywords: Set<String> = []
    let keywords = ["행복", "감정적", "여유", "에너지", "추억", "힐링", "파티", "드라이브"]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("특별한 당신의 취향, 소곤소곤 들려주세요.")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 16) {
                    WrapHStack(items: keywords, spacing: 8, alignment: .leading) { keyword in
                        Text(keyword)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedKeywords.contains(keyword) ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
                            .foregroundColor(selectedKeywords.contains(keyword) ? .white : .white.opacity(0.8))
                            .cornerRadius(16)
                            .onTapGesture {
                                if selectedKeywords.contains(keyword) {
                                    selectedKeywords.remove(keyword)
                                } else {
                                    selectedKeywords.insert(keyword)
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 40)
                Button("다음 →", action: onNext)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.7))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
            }
            .padding()
        }
    }
} 
