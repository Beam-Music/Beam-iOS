//
//  OnboardTasteView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardTasteView: View {
    let onNext: () -> Void
    @State private var selectedArtists: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    let artists = ["정진태", "Coldplay", "Bruno Mars", "Lenny", "Taylor Swift", "The 1975", "SZA", "ADOY"]
    let genres = ["발라드", "댄스", "힙합", "록"]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("특별한 당신의 취향, 소곤소곤 들려주세요.")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 16) {
                    Text("가수로 찾기")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    WrapHStack(items: artists, spacing: 8, alignment: .leading) { artist in
                        Text(artist)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedArtists.contains(artist) ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
                            .foregroundColor(selectedArtists.contains(artist) ? .white : .white.opacity(0.8))
                            .cornerRadius(16)
                            .onTapGesture {
                                if selectedArtists.contains(artist) {
                                    selectedArtists.remove(artist)
                                } else {
                                    selectedArtists.insert(artist)
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                VStack(alignment: .leading, spacing: 16) {
                    Text("장르로 찾기")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    WrapHStack(items: genres, spacing: 8, alignment: .leading) { genre in
                        Text(genre)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedGenres.contains(genre) ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
                            .foregroundColor(selectedGenres.contains(genre) ? .white : .white.opacity(0.8))
                            .cornerRadius(16)
                            .onTapGesture {
                                if selectedGenres.contains(genre) {
                                    selectedGenres.remove(genre)
                                } else {
                                    selectedGenres.insert(genre)
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

// FlexibleView는 Chip/Tag 레이아웃을 위한 유틸리티입니다. (구현 필요) 
