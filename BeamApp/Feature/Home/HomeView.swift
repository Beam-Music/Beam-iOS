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
    @State private var hitSongs: [MusicSearchResult] = []
    @State private var remixArtistPairs: [RemixArtistPair] = []
    @State private var songToAddToPlaylist: MusicSearchResult? = nil
    @State private var isPlaylistSelectSheetPresented: Bool = false
    
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
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("히트 음악")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Button("전체보기") {
                                // 전체보기 액션 (필요시)
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        }
                        .padding(.horizontal)
                        Spacer().frame(height: 10)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                ForEach(hitSongs.indices, id: \.self) { idx in
                                    let song = hitSongs[idx]
                                    HitSongCardView(
                                        song: song,
                                        onPlay: {
                                            viewStore.send(.playMusic(song))
                                            isMiniPlayerVisible = true
                                        },
                                        onAdd: {
                                            songToAddToPlaylist = song
                                            isPlaylistSelectSheetPresented = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        // 리믹스할 가수조합 추천 섹션
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("리믹스할 가수조합 추천")
                                    .font(.title2).bold()
                                    .foregroundColor(.white)
                                Spacer()
                                Button("전체보기") {
                                    // 전체보기 액션 (필요시)
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .font(.subheadline)
                            }
                            .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 32) {
                                    ForEach(remixArtistPairs) { pair in
                                        RemixArtistPairView(pair: pair)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
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
                await fetchAppleMusicHitSongs()
                await fetchRemixArtistPairs()
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
    
    // 실시간 차트 곡 불러오는 함수
    private func fetchAppleMusicHitSongs() async {
        do {
            var request = MusicCatalogChartsRequest(types: [MusicKit.Song.self])
            request.limit = 10
            let response = try await request.response()
            let topSongs = response.songCharts.first?.items ?? []
            let results = topSongs.map { song in
                MusicSearchResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artworkURL: song.artwork?.url(width: 100, height: 100),
                    isExplicit: song.contentRating == .explicit
                )
            }
            hitSongs = results
        } catch {
            // 에러 처리 (예: 네트워크 오류, 권한 오류 등)
        }
    }

    // MARK: - 리믹스 가수조합 데이터 및 뷰
    struct RemixArtistPair: Identifiable {
        let id = UUID()
        let artist1: String
        let artist2: String
        var artworkURL1: URL?
        var artworkURL2: URL?
    }

    struct RemixArtistPairView: View {
        let pair: RemixArtistPair
        var body: some View {
            VStack(spacing: 10) {
                ZStack {
                    if let url1 = pair.artworkURL1 {
                        AsyncImage(url: url1) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: true))
                    }
                    if let url2 = pair.artworkURL2 {
                        AsyncImage(url: url2) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: false))
                    }
                }
                .frame(width: 100, height: 100)
                Button(action: { /* 청음하기 액션 */ }) {
                    HStack(spacing: 4) {
                        Text("청음하기")
                        Image(systemName: "play.circle.fill")
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                }
            }
        }
    }

    struct HalfCircle: Shape {
        let left: Bool
        func path(in rect: CGRect) -> Path {
            var path = Path()
            if left {
                path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
                path.closeSubpath()
            } else {
                path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.closeSubpath()
            }
            return path
        }
    }

    // 가수조합을 MusicKit으로 검색해서 artworkURL을 채움 (데모용 하드코딩)
    private func fetchRemixArtistPairs() async {
        let pairs = [
            ("Dua Lipa", "H.E.R"),
            ("Rihanna", "BlackPink"),
            ("WOODZ", "NewJeans")
        ]
        var result: [RemixArtistPair] = []
        for (a1, a2) in pairs {
            let url1 = await fetchArtistArtworkURL(artist: a1)
            let url2 = await fetchArtistArtworkURL(artist: a2)
            result.append(RemixArtistPair(artist1: a1, artist2: a2, artworkURL1: url1, artworkURL2: url2))
        }
        await MainActor.run { self.remixArtistPairs = result }
    }

    private func fetchArtistArtworkURL(artist: String) async -> URL? {
        do {
            let request = MusicCatalogSearchRequest(term: artist, types: [MusicKit.Artist.self])
            let response = try await request.response()
            if let artist = response.artists.first, let url = artist.artwork?.url(width: 200, height: 200) {
                return url
            }
        } catch {}
        return nil
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
    let onAdd: () -> Void
    @State private var fetchedArtworkURL: URL? = nil
    @State private var isFetching: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let url = song.artworkURL ?? fetchedArtworkURL {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 110, height: 110)
                    .cornerRadius(16)
                } else if isFetching {
                    ProgressView()
                        .frame(width: 110, height: 110)
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
        }
        .frame(width: 130)
        .onAppear {
            if song.artworkURL == nil && !isFetching {
                isFetching = true
                Task {
                    let service = MusicSearchService()
                    do {
                        let results = try await service.searchMusic(query: "\(song.title) \(song.artist)")
                        if let first = results.first, let url = first.artworkURL {
                            fetchedArtworkURL = url
                        }
                    } catch {}
                    isFetching = false
                }
            }
        }
    }
}
