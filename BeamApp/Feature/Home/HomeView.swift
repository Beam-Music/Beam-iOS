//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

// 별 데이터 모델
struct Star: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// 별 배경 뷰
struct StarFieldView: View {
    let starCount: Int
    let scrollOffset: CGFloat
    @State private var stars: [Star] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(
                            x: star.x * geo.size.width,
                            y: (star.y * geo.size.height + scrollOffset).truncatingRemainder(dividingBy: geo.size.height)
                        )
                }
            }
            .onAppear {
                if stars.isEmpty {
                    stars = (0..<starCount).map { _ in
                        Star(
                            x: .random(in: 0...1),
                            y: .random(in: 0...1),
                            size: .random(in: 2...7),
                            opacity: .random(in: 0.3...0.9)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// 스크롤 오프셋 추적용 PreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PlaylistRowView: View {
    let playlist: PlaylistSummaryDTO
    let onPlayTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
            Button(action: onPlayTapped) {
                Image(systemName: "play.fill")
                    .foregroundColor(Color.purple)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color.purple.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Navigation Bar View
struct HomeNavigationBarView: View {
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationLink(destination: SettingsView(isLoggedIn: $isLoggedIn)) {
            Image(systemName: "gearshape")
                .font(.system(size: 20))
                .foregroundColor(Color.purple)
        }
    }
}

// MARK: - Playlist List View
struct PlaylistListView: View {
    let playlists: [PlaylistSummaryDTO]
    let onPlaylistSelected: (PlaylistSummaryDTO) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List(playlists, id: \.id) { playlist in
            PlaylistRowView(
                playlist: playlist,
                onPlayTapped: { onPlaylistSelected(playlist) }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<HomeReducer>
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            StarFieldView(starCount: 40, scrollOffset: scrollOffset)
            VStack(spacing: 0) {
                HStack {
                    TextField("노래/가수 검색하기", text: $searchText)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .medium))
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                // 스크롤뷰와 오프셋 추적
                ScrollView {
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
                    }
                    .frame(height: 0)
                    Spacer()
                    HStack {
                        Spacer(minLength: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 1, y: 2)
                        )
                        .padding(.leading, 24)
                        Spacer()
                    }
                    Spacer()
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
        }
    }
}

//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(isLoggedIn: .constant(true))
//    }
//}
