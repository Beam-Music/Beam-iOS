//
//  OnboardKeywordView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25
import SwiftUI

struct OnboardKeywordView: View {
    let onNext: () -> Void
    @State private var selectedArtists: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    @State private var animatedArtistIDs: Set<String> = []
    let artists = ["Jin Tae Jung", "Coldplay", "Bruno Mars", "Lenny", "Taylor Swift", "The 1975", "SZA", "ADOY"]
    let genres = ["Ballad", "Dance", "Hip Hop", "Rock"]

    let chipHorizontalPadding: CGFloat = 16
    let chipVerticalPadding: CGFloat = 8
    let chipHeight: CGFloat = 32
    let chipSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("Your unique taste,\ntell us quietly.")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            VStack(alignment: .leading, spacing: 16) {
                Text("Find by Artist")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                ChipGridView(
                    data: artists.map { ChipItem(id: $0, name: $0) },
                    selectedItems: $selectedArtists,
                    animatedArtistIDs: $animatedArtistIDs,
                    chipHorizontalPadding: chipHorizontalPadding,
                    chipVerticalPadding: chipVerticalPadding,
                    chipHeight: chipHeight,
                    chipSpacing: chipSpacing,
                    rowSpacing: rowSpacing
                )
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 16) {
                Text("Find by Genre")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                ChipGridView(
                    data: genres.map { ChipItem(id: $0, name: $0) },
                    selectedItems: $selectedGenres,
                    animatedArtistIDs: $animatedArtistIDs,
                    chipHorizontalPadding: chipHorizontalPadding,
                    chipVerticalPadding: chipVerticalPadding,
                    chipHeight: chipHeight,
                    chipSpacing: chipSpacing,
                    rowSpacing: rowSpacing
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Next →", action: onNext)
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
