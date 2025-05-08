//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

//
//  OnboardKeywordView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI


// MARK: - OnboardKeywordView

import SwiftUI

struct OnboardKeywordView: View {
    let onNext: () -> Void
    @State private var selectedArtists: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    let artists = ["정진태", "Coldplay", "Bruno Mars", "Lenny", "Taylor Swift", "The 1975", "SZA", "ADOY"]
    let genres = ["발라드", "댄스", "힙합", "록"]

    let chipHorizontalPadding: CGFloat = 16
    let chipVerticalPadding: CGFloat = 8
    let chipHeight: CGFloat = 32
    let chipSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("특별한 당신의 취향,\n소곤소곤 들려주세요.")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            VStack(alignment: .leading, spacing: 16) {
                Text("가수로 찾기")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                ChipGridView(
                    data: artists.map { ChipItem(id: $0, name: $0) },
                    selectedItems: $selectedArtists,
                    chipHorizontalPadding: chipHorizontalPadding,
                    chipVerticalPadding: chipVerticalPadding,
                    chipHeight: chipHeight,
                    chipSpacing: chipSpacing,
                    rowSpacing: rowSpacing
                )
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 16) {
                Text("장르로 찾기")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                ChipGridView(
                    data: genres.map { ChipItem(id: $0, name: $0) },
                    selectedItems: $selectedGenres,
                    chipHorizontalPadding: chipHorizontalPadding,
                    chipVerticalPadding: chipVerticalPadding,
                    chipHeight: chipHeight,
                    chipSpacing: chipSpacing,
                    rowSpacing: rowSpacing
                )
            }
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
        }
        .padding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 155/255, green: 78/255, blue: 166/255), Color(red: 224/255, green: 122/255, blue: 175/255)]), startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }
}
