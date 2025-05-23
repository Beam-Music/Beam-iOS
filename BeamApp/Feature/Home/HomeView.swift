//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import MusicKit

struct MusicSearchResult: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let isExplicit: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MusicSearchResult, rhs: MusicSearchResult) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Music Search Service
class MusicSearchService {
    func searchMusic(query: String) async throws -> [MusicSearchResult] {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw NSError(domain: "MusicAuthorizationFailed", code: 401)
        }
        var searchRequest = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
        searchRequest.limit = 25
        let response = try await searchRequest.response()
        let songResults: [MusicSearchResult] = response.songs.compactMap { song in
            MusicSearchResult(
                id: song.id.rawValue,
                title: song.title,
                artist: song.artistName,
                artworkURL: song.artwork?.url(width: 100, height: 100),
                isExplicit: song.contentRating == .explicit
            )
        }
        return songResults
    }
}

// MARK: - Music Search Result View
struct MusicSearchResultView: View {
    let result: MusicSearchResult
    let onPlay: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            Group {
                if let artworkURL = result.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                        .background(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                    
                    if result.isExplicit {
                        Text("E")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(3)
                    }
                }
                
                Text(result.artist)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .gray : .gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
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

// MARK: - Updated HomeView
struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<HomeReducer>
    let libraryStore: StoreOf<LibraryReducer>
    @ObservedObject var viewStore: ViewStore<HomeReducer.State, HomeReducer.Action>
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0
    
    // 히트 음악 임시 데이터 (id 제거)
    private let hitSongs: [(title: String, artist: String, artworkURL: URL?, isExplicit: Bool)] = [
        ("Fall in Love with You", "Montell Fish", URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/7e/2e/2d/7e2e2d2e-2e2d-7e2e-2d2e-7e2e2d2e2d2e/cover.jpg/200x200bb.jpg"), false),
        ("Another Song", "Artist Name", nil, false),
        ("Sample Hit", "Sample Artist", nil, true)
    ]
    
    init(isLoggedIn: Binding<Bool>, isMiniPlayerVisible: Binding<Bool>, store: StoreOf<HomeReducer>, libraryStore: StoreOf<LibraryReducer>) {
        self._isLoggedIn = isLoggedIn
        self._isMiniPlayerVisible = isMiniPlayerVisible
        self.store = store
        self.libraryStore = libraryStore
        self.viewStore = ViewStore(store, observe: { $0 })
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated star field background
            StarFieldView(starCount: 40, scrollOffset: scrollOffset)
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("노래/가수 검색하기", text: viewStore.binding(
                        get: \.searchText,
                        send: HomeReducer.Action.searchTextChanged
                    ))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .medium))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    if !viewStore.searchText.isEmpty {
                        Button(action: {
                            viewStore.send(.clearSearchResults)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("히트 음악")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Button("전체보기") {
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(hitSongs.indices, id: \.self) { idx in
                                    makeHitSongCard(song: hitSongs[idx])
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 12)
                    
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
                    }
                    .frame(height: 0)
                    
                    if viewStore.isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .padding(.top, 20)
                    }
                    
                    if let error = viewStore.error {
                        Text("검색 오류: \(error)")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.5))
                            .cornerRadius(8)
                            .padding()
                    }
                    
                    if !viewStore.searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Text("검색 결과")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            ForEach(viewStore.searchResults) { result in
                                MusicSearchResultView(result: result) {
                                    viewStore.send(.playMusic(result))
                                    isMiniPlayerVisible = true
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    else if viewStore.searchText.isEmpty {
                        if !viewStore.playlists.isEmpty {
                            PlaylistListView(
                                playlists: viewStore.playlists,
                                onPlaylistSelected: { playlist in
                                    viewStore.send(.playlistSelected(playlist))
                                }
                            )
                        } else {
                            // VStack(spacing: 16) {
                            //     Text("재생 목록이 없습니다")
                            //         .font(.headline)
                            //         .foregroundColor(.white)
                            //         .padding(.top, 40)
                                
                            //     Text("첫 번째 재생 목록을 만들어보세요!")
                            //         .font(.subheadline)
                            //         .foregroundColor(.white.opacity(0.8))
                            // }
                            // .frame(maxWidth: .infinity)
                            // .padding(.top, 60)
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }

            MusicSearchView(isMiniPlayerVisible: $isMiniPlayerVisible)
        }
        .navigationBarItems(trailing: HomeNavigationBarView(isLoggedIn: $isLoggedIn))
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            Task {
                let status = await MusicAuthorization.request()
                print("MusicKit authorization status: \(status.rawValue)")
            }
        }
        .sheet(
            store: store.scope(
                state: \.$playerState,
                action: HomeReducer.Action.player
            ),
            onDismiss: {
                // 필요시 미니플레이어 등 상태 처리
            }
        ) { playerStore in
            PlayerView(
                store: playerStore,
                isMiniPlayerVisible: $isMiniPlayerVisible,
                libraryStore: libraryStore
            )
        }
    }
    
    // 히트 음악 카드 뷰 생성 함수
    private func makeHitSongCard(song: (title: String, artist: String, artworkURL: URL?, isExplicit: Bool)) -> some View {
        HitSongCardView(
            song: MusicSearchResult(
                id: UUID().uuidString,
                title: song.title,
                artist: song.artist,
                artworkURL: song.artworkURL,
                isExplicit: song.isExplicit
            ),
            onPlay: {
                Task {
                    let service = MusicSearchService()
                    do {
                        let results = try await service.searchMusic(query: "\(song.title) \(song.artist)")
                        if let first = results.first {
                            viewStore.send(.playMusic(first))
                            isMiniPlayerVisible = true
                        } else {
                            // 곡을 찾지 못함: 에러 처리
                        }
                    } catch {
                        // 에러 처리
                    }
                }
            }
        )
    }
}

// MARK: - Setup for Previews
extension PlaylistSummaryDTO {
    static let mockPlaylists: [PlaylistSummaryDTO] = [
        PlaylistSummaryDTO(id: UUID(), name: "좋아하는 노래"),
        PlaylistSummaryDTO(id: UUID(), name: "드라이브 음악", user: PlaylistSummaryDTO.User(id: UUID(), username: "사용자")),
        PlaylistSummaryDTO(id: UUID(), name: "Work Out")
    ]
}

// struct HomeView_Previews: PreviewProvider {
//     static var previews: some View {
//         NavigationView {
//             HomeView(
//                 isLoggedIn: .constant(true),
//                 isMiniPlayerVisible: .constant(false),
//                 store: Store(
//                     initialState: HomeReducer.State(
//                         playlists: PlaylistSummaryDTO.mockPlaylists
//                     ),
//                     reducer: HomeReducer()
//                 )
//             )
//         }
//     }
// }

struct Star: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PlaylistListView: View {
    let playlists: [PlaylistSummaryDTO]
    let onPlaylistSelected: (PlaylistSummaryDTO) -> Void
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        List(playlists, id: \.id) { playlist in
            Button(action: { onPlaylistSelected(playlist) }) {
                Text(playlist.name)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct MusicSearchView: View {
    @Binding var isMiniPlayerVisible: Bool
    var body: some View {
        EmptyView()
    }
}

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

struct HitSongCardView: View {
    let song: MusicSearchResult
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let url = song.artworkURL {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .frame(width: 110, height: 110)
                            .cornerRadius(16)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                            .frame(width: 110, height: 110)
                            .cornerRadius(16)
                    }
                } else {
                    Color.gray.opacity(0.2)
                        .frame(width: 110, height: 110)
                        .cornerRadius(16)
                }
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .padding(8)
            }
            Text(song.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Text("1M+ loved, 3M+ played")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: 120)
    }
}
