//
//  OnboardTasteView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI
import MusicKit

struct OnboardTasteView: View {
    let onNext: () -> Void
    @State private var selectedArtists: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    @State private var animatedArtistIDs: Set<String> = []
    let artists = [
        ChipItem(id: "백예린", name: "백예린"),
        ChipItem(id: "김정치마", name: "김정치마"),
        ChipItem(id: "혁오", name: "혁오"),
        ChipItem(id: "Coldplay", name: "Coldplay"),
        ChipItem(id: "Bruno Mars", name: "Bruno Mars"),
        ChipItem(id: "Lenny", name: "Lenny"),
        ChipItem(id: "Taylor Swift", name: "Taylor Swift"),
        ChipItem(id: "The 1975", name: "The 1975"),
        ChipItem(id: "SZA", name: "SZA"),
        ChipItem(id: "ADOY", name: "ADOY")
    ]
    let genres = ["발라드", "댄스", "힙합", "록"]

    let chipHorizontalPadding: CGFloat = 16
    let chipVerticalPadding: CGFloat = 8
    let chipHeight: CGFloat = 40
    let chipSpacing: CGFloat = 12
    let rowSpacing: CGFloat = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("특별한 당신의 취향,")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("소곤소곤 들려주세요.")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 0) {
                        ForEach(1...3, id: \.self) { idx in
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(idx == 2 ? Color.purple : Color.white.opacity(0.4))
                                        .frame(width: 32, height: 32)
                                    Text("\(idx)")
                                        .foregroundColor(idx == 2 ? .white : .purple)
                                        .fontWeight(.bold)
                                }
                                Text(idx == 1 ? "회원가입" : idx == 2 ? "아티스트 & 곡 선택" : "완료")
                                    .font(.caption)
                                    .foregroundColor(idx == 2 ? .purple : .white.opacity(0.7))
                            }
                            if idx < 3 {
                                Rectangle()
                                    .fill(idx == 2 ? Color.purple : Color.white.opacity(0.4))
                                    .frame(width: 40, height: 2)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                }

                Text("아티스트 & 곡 선택")
                    .font(.headline)
                    .foregroundColor(Color("5C1769"))
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                // 가수로 찾기
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("가수로 찾기")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ForEach(artists.prefix(artists.count/2), id: \.id) { artist in
                                    ArtistChipView(
                                        artistName: artist.name,
                                        isSelected: selectedArtists.contains(artist.id),
                                        size: 110,
                                        onTap: {
                                            withAnimation {
                                                if selectedArtists.contains(artist.id) {
                                                    selectedArtists.remove(artist.id)
                                                } else {
                                                    selectedArtists.insert(artist.id)
                                                }
                                            }
                                        },
                                        showFirstSelectEffect: false,
                                        showCheck: selectedArtists.contains(artist.id)
                                    )
                                }
                            }
                            HStack(spacing: 16) {
                                ForEach(artists.suffix(artists.count/2), id: \.id) { artist in
                                    ArtistChipView(
                                        artistName: artist.name,
                                        isSelected: selectedArtists.contains(artist.id),
                                        size: 110,
                                        onTap: {
                                            withAnimation {
                                                if selectedArtists.contains(artist.id) {
                                                    selectedArtists.remove(artist.id)
                                                } else {
                                                    selectedArtists.insert(artist.id)
                                                }
                                            }
                                        },
                                        showFirstSelectEffect: false,
                                        showCheck: selectedArtists.contains(artist.id)
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 2*110 + 16)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // 장르로 찾기
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("장르로 찾기")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ForEach(genres.prefix(genres.count/2), id: \.self) { genre in
                                    GenreChipView(
                                        genre: genre,
                                        isSelected: selectedGenres.contains(genre),
                                        size: 110,
                                        onTap: {
                                            withAnimation {
                                                if selectedGenres.contains(genre) {
                                                    selectedGenres.remove(genre)
                                                } else {
                                                    selectedGenres.insert(genre)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                            HStack(spacing: 16) {
                                ForEach(genres.suffix(genres.count/2), id: \.self) { genre in
                                    GenreChipView(
                                        genre: genre,
                                        isSelected: selectedGenres.contains(genre),
                                        size: 110,
                                        onTap: {
                                            withAnimation {
                                                if selectedGenres.contains(genre) {
                                                    selectedGenres.remove(genre)
                                                } else {
                                                    selectedGenres.insert(genre)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 2*110 + 16)
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer(minLength: 60)
            }
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {}
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onNext()
                }
            }) {
                Text("다음 →")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.trailing, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 155/255, green: 78/255, blue: 166/255), Color(red: 224/255, green: 122/255, blue: 175/255)]),
                startPoint: .top, endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}

struct ChipItem: ChipData, Identifiable {
    public let id: String
    public let name: String
    public var imageURL: URL?

    var description: String { name }

    func chipWidth(horizontalPadding: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (name as NSString).size(withAttributes: attributes)
        return size.width + horizontalPadding * 2
    }
}

struct ChipGridView<Item: ChipData, Data: RandomAccessCollection>: View where Data.Element == Item {
    let data: Data
    @Binding var selectedItems: Set<Item.ID>
    @Binding var animatedArtistIDs: Set<Item.ID>
    let chipHorizontalPadding: CGFloat
    let chipVerticalPadding: CGFloat
    let chipHeight: CGFloat
    let chipSpacing: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let rows = computeRows(in: totalWidth)

            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: chipSpacing) {
                        ForEach(row) { item in
                            chip(for: item)
                        }
                    }
                }
            }
            .frame(height: CGFloat(rows.count) * (chipHeight + rowSpacing) - rowSpacing)
        }
    }

    private func computeRows(in totalWidth: CGFloat) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var currentRowWidth: CGFloat = 0

        for item in data {
            let itemWidth = item.chipWidth(horizontalPadding: chipHorizontalPadding)
            if currentRowWidth + itemWidth + chipSpacing > totalWidth {
                rows.append([item])
                currentRowWidth = itemWidth + itemWidth + chipSpacing
            } else {
                if let lastRow = rows.last {
                    rows[rows.count - 1].append(item)
                    currentRowWidth += itemWidth + chipSpacing
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private func chip(for item: Item) -> some View {
        let isSelected = selectedItems.contains(item.id)
        let size = CGFloat(Int.random(in: 100...120))
        if let chipItem = item as? ChipItem, item.id == item.description {
            let showFirstSelectEffect = isSelected && !animatedArtistIDs.contains(item.id)
            ArtistChipView(
                artistName: chipItem.description,
                isSelected: isSelected,
                size: size,
                onTap: {
                    withAnimation {
                        if isSelected {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                            if !animatedArtistIDs.contains(item.id) {
                                animatedArtistIDs.insert(item.id)
                            }
                        }
                    }
                },
                showFirstSelectEffect: showFirstSelectEffect,
                showCheck: isSelected
            )
        } else {
            Text(item.description)
                .padding(.horizontal, chipHorizontalPadding)
                .padding(.vertical, chipVerticalPadding)
                .frame(height: chipHeight, alignment: .center)
                .background(isSelected ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .cornerRadius(16)
                .onTapGesture {
                    withAnimation {
                        if isSelected {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                }
        }
    }
}

struct ArtistChipView: View {
    let artistName: String
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void
    let showFirstSelectEffect: Bool
    let showCheck: Bool
    @State private var imageURL: URL?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                if let url = imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                            .frame(width: size, height: size)
                            .background(Color.gray.opacity(0.2))
                    }
                } else {
                    Color.gray.opacity(0.2)
                }
                Text(artistName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
                    .padding([.leading, .bottom], 8)
            }
            if showCheck {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.purple))
                    .offset(x: -8, y: 8)
                    .transition(.scale)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 4)
                .shadow(color: isSelected ? .purple.opacity(0.5) : .clear, radius: 10)
        )
        .scaleEffect(showFirstSelectEffect ? 1.15 : 1.0)
        .animation(showFirstSelectEffect ? .spring(response: 0.4, dampingFraction: 0.5) : .none, value: showFirstSelectEffect)
        .onTapGesture { onTap() }
        .onAppear {
            fetchArtistImageURL(artistName: artistName) { url in
                self.imageURL = url
            }
        }
    }
}

func fetchArtistImageURL(artistName: String, completion: @escaping (URL?) -> Void) {
    Task {
        let artistType: any MusicCatalogSearchable.Type = MusicKit.Artist.self
        var request = MusicCatalogSearchRequest(term: artistName, types: [artistType])
        request.limit = 1
        let response = try? await request.response()
        if let artist = response?.artists.first, let artwork = artist.artwork {
            let url = artwork.url(width: 200, height: 200)
            completion(url)
        } else {
            completion(nil)
        }
    }
}

protocol ChipData: Hashable, Identifiable {
    var id: String { get }
    func chipWidth(horizontalPadding: CGFloat) -> CGFloat
    var description: String { get }
}

struct GenreChipView: View {
    let genre: String
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void
    @State private var imageURL: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .frame(width: size, height: size)
                        .background(Color.gray.opacity(0.2))
                }
            } else {
                Color.gray.opacity(isSelected ? 0.4 : 0.2)
            }
            Text(genre)
                .font(.headline)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
                .padding([.leading, .bottom], 8)
        }
        .frame(width: size, height: size)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 4)
                .shadow(color: isSelected ? .purple.opacity(0.5) : .clear, radius: 10)
        )
        .onTapGesture { onTap() }
        .onAppear {
            fetchGenreImageURL(genre: genre) { url in
                self.imageURL = url
            }
        }
    }
}

func fetchGenreImageURL(genre: String, completion: @escaping (URL?) -> Void) {
    let genreImageURLs: [String: String] = [
        "발라드": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Ballad.jpg/1200px-Ballad.jpg",
        "댄스": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5d/Dance.jpg/1200px-Dance.jpg",
        "힙합": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Hiphop.jpg/1200px-Hiphop.jpg",
        "록": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Rock.jpg/1200px-Rock.jpg"
    ]
    let url = URL(string: genreImageURLs[genre] ?? "")
    completion(url)
}
