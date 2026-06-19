//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

// MARK: - AI Convert Helper Functions
func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
    Task {
        do {
            let audioData = try Data(contentsOf: fileURL)
            let convertedAudioData = try await voiceConversionService.convert(
                audioData: audioData,
                voiceId: "ALEX_KAYE",
                voiceType: nil
            )
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ai_version.mp3")
            try convertedAudioData.write(to: tempURL)
            await MainActor.run { completion(.success(tempURL)) }
        } catch {
            await MainActor.run { completion(.failure(error)) }
        }
    }
}

struct MusicSearchResult: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let isExplicit: Bool
    let playbackURL: String?
    let genre: String?
    
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
        let tracks = try await AudiusService.shared.searchTracks(query: query, limit: 25)
        return tracks.map { $0.toMusicSearchResult() }
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

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<AppReducer>
    let libraryStore: StoreOf<LibraryReducer>
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var hitSongs: [MusicSearchResult] = []
    @State private var remixArtistPairs: [RemixArtistPair] = []
    @State private var songToAddToPlaylist: MusicSearchResult? = nil
    @State private var isPlaylistSelectSheetPresented: Bool = false
    @State private var isLoadingHitSongs: Bool = true
    @State private var isLoadingRemixPairs: Bool = true
    @State private var isRemixingDemo = false
    @State private var showAllHitSongsSheet = false
    @State private var showAllRemixPairsSheet = false
    @State private var showSearchScreen = false
    @State private var searchDraft = ""
    @State private var recentSearches: [String] = []
    @FocusState private var isSearchFieldFocused: Bool
    
    private var homeStore: StoreOf<HomeReducer> {
        store.scope(state: \.tabBarState.homeState, action: { AppReducer.Action.tabBar(.home($0)) })
    }
    private var viewStore: ViewStore<HomeReducer.State, HomeReducer.Action> {
        ViewStore(homeStore, observe: { $0 })
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
                Button(action: {
                    searchDraft = viewStore.searchText
                    showSearchScreen = true
                }) {
                    HStack {
                        Text(viewStore.searchText.isEmpty ? "노래/가수 검색하기" : viewStore.searchText)
                            .foregroundColor(viewStore.searchText.isEmpty ? .white.opacity(0.35) : .white)
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("인기 음악")
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            Spacer()
                            Button("전체보기") {
                                showAllHitSongsSheet = true
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Audius 트렌딩 기준으로 집계된 재생 가능한 인기 곡이에요")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.9))

                            Text("음성 변환 테스트는 먼저 아래 인기 곡을 재생한 뒤 진행해 주세요")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.horizontal)

                        Spacer().frame(height: 10)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                if isLoadingHitSongs {
                                    // 로딩 중일 때 플레이스홀더
                                    ForEach(0..<5, id: \.self) { _ in
                                        HitSongCardPlaceholder()
                                    }
                                } else {
                                    ForEach(hitSongs.indices, id: \.self) { idx in
                                        let song = hitSongs[idx]
                                        HitSongCardView(
                                            song: song,
                                            onPlay: {
                                                isSearchFieldFocused = false
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
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        .frame(height: 180) // 고정된 높이 설정
                        // 리믹스할 가수조합 추천 섹션
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("리믹스할 가수조합 추천")
                                    .font(.title2).bold()
                                    .foregroundColor(.white)
                                Spacer()
                                Button("전체보기") {
                                    showAllRemixPairsSheet = true
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .font(.subheadline)
                            }
                            .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 32) {
                                    if isLoadingRemixPairs {
                                        // 로딩 중일 때 플레이스홀더
                                        ForEach(0..<3, id: \.self) { _ in
                                            RemixArtistPairPlaceholder()
                                        }
                                    } else {
                                        ForEach(remixArtistPairs) { pair in
                                            RemixArtistPairView(pair: pair, onRemix: {
                                                performRemix(for: pair)
                                            })
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 10)
                            .frame(height: 150) // 고정된 높이 설정
                        }
                    }
                    .padding(.top, 20)
                    
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
                    }
                    .frame(height: 0)
                    
                    if viewStore.searchText.isEmpty {
                        if !viewStore.playlists.isEmpty {
                            PlaylistListView(
                                playlists: viewStore.playlists,
                                onPlaylistSelected: { playlist in
                                    viewStore.send(.playlistSelected(playlist))
                                }
                            )
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .onTapGesture {
                    isSearchFieldFocused = false
                }
            }

        }
        .navigationBarItems(trailing: HomeNavigationBarView(store: store, isLoggedIn: $isLoggedIn))
        .navigationBarTitle("", displayMode: .inline)
        .onAppear {
            recentSearches = loadRecentSearches()
            Task {
                await fetchTrendingSongs()
                await fetchRemixArtistPairs()
            }
        }
        .fullScreenCover(isPresented: $showSearchScreen) {
            SearchScreenView(
                searchText: $searchDraft,
                results: viewStore.searchResults,
                isSearching: viewStore.isSearching,
                recentSearches: recentSearches,
                suggestedSearches: ["pop", "dua lipa", "taylor swift", "weeknd", "newjeans", "house", "hip hop"],
                onClose: {
                    showSearchScreen = false
                },
                onChangeText: { text in
                    searchDraft = text
                    if text.isEmpty {
                        viewStore.send(.clearSearchResults)
                    } else {
                        viewStore.send(.searchTextChanged(text))
                    }
                },
                onSubmitSearch: { keyword in
                    addRecentSearch(keyword)
                    if keyword.isEmpty {
                        viewStore.send(.clearSearchResults)
                    } else {
                        viewStore.send(.searchTextChanged(keyword))
                    }
                },
                onSelectRecent: { keyword in
                    searchDraft = keyword
                    addRecentSearch(keyword)
                    viewStore.send(.searchTextChanged(keyword))
                },
                onDeleteRecent: { keyword in
                    recentSearches.removeAll { $0 == keyword }
                    saveRecentSearches(recentSearches)
                },
                onClearRecent: {
                    recentSearches.removeAll()
                    saveRecentSearches([])
                },
                onPlay: { result in
                    addRecentSearch(result.title + " " + result.artist)
                    showSearchScreen = false
                    viewStore.send(.playMusic(result))
                    isMiniPlayerVisible = true
                }
            )
        }
        .sheet(isPresented: $showAllHitSongsSheet) {
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(hitSongs) { song in
                            MusicSearchResultView(result: song) {
                                showAllHitSongsSheet = false
                                isSearchFieldFocused = false
                                viewStore.send(.playMusic(song))
                                isMiniPlayerVisible = true
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.95), Color.pink.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("Audius 인기 음악")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showAllRemixPairsSheet) {
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(remixArtistPairs) { pair in
                            VStack(alignment: .leading, spacing: 12) {
                                RemixArtistPairView(pair: pair, onRemix: {
                                    showAllRemixPairsSheet = false
                                    performRemix(for: pair)
                                })
                                .frame(maxWidth: .infinity)

                                Text("\(pair.artist1) × \(pair.artist2)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(20)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.95), Color.pink.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("리믹스 가능한 가수 조합")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // Audius 인기 곡 불러오기
    private func fetchTrendingSongs() async {
        do {
            let trendingTracks = try await AudiusService.shared.getTrendingTracks(limit: 100)
            let playableTracks = trendingTracks
                .map { $0.toMusicSearchResult() }
                .filter { $0.playbackURL != nil }

            await MainActor.run {
                self.hitSongs = Array(playableTracks.prefix(20))
                self.isLoadingHitSongs = false
            }
        } catch {
            print("Failed to fetch Audius popular tracks: \(error)")
            await MainActor.run {
                self.isLoadingHitSongs = false
            }
        }
    }

    // MARK: - 리믹스 가수조합 데이터 및 뷰
    struct RemixArtistPair: Identifiable {
        let id = UUID()
        let artist1: String
        let artist2: String
        var artworkURL1: URL?
        var artworkURL2: URL?
        let track1: MusicSearchResult
        let track2: MusicSearchResult
    }

    struct RemixArtistPairView: View {
        let pair: RemixArtistPair
        var onRemix: (() -> Void)?

        var body: some View {
            VStack(spacing: 10) {
                ZStack {
                    HalfCircle(left: true)
                        .fill(Color.white.opacity(0.12))
                    HalfCircle(left: false)
                        .fill(Color.white.opacity(0.12))

                    if let url1 = pair.artworkURL1 {
                        AsyncImage(url: url1) { image in
                            image.resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: true))
                    }
                    if let url2 = pair.artworkURL2 {
                        AsyncImage(url: url2) { image in
                            image.resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .clipShape(HalfCircle(left: false))
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                VStack(spacing: 2) {
                    Text(pair.artist1)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(pair.artist2)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(width: 120)

                Button(action: {
                    onRemix?()
                }) {
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

    // Audius에서 실제 재생 가능한 pop 계열 아티스트 조합 생성
    private func fetchRemixArtistPairs() async {
        do {
            let tracks = try await AudiusService.shared.searchTracks(query: "pop", limit: 30)
            let candidates = tracks
                .map { $0.toMusicSearchResult() }
                .filter { $0.playbackURL != nil && $0.artworkURL != nil }

            var uniqueArtists: [MusicSearchResult] = []
            var seenArtists = Set<String>()
            for track in candidates {
                let key = track.artist.lowercased()
                if !seenArtists.contains(key) {
                    seenArtists.insert(key)
                    uniqueArtists.append(track)
                }
            }

            var result: [RemixArtistPair] = []
            var index = 0
            while index + 1 < uniqueArtists.count, result.count < 8 {
                let first = uniqueArtists[index]
                let second = uniqueArtists[index + 1]
                result.append(
                    RemixArtistPair(
                        artist1: first.artist,
                        artist2: second.artist,
                        artworkURL1: first.artworkURL,
                        artworkURL2: second.artworkURL,
                        track1: first,
                        track2: second
                    )
                )
                index += 2
            }

            await MainActor.run {
                self.remixArtistPairs = result
                self.isLoadingRemixPairs = false
            }
        } catch {
            print("Failed to fetch remix artist pairs: \(error)")
            await MainActor.run {
                self.isLoadingRemixPairs = false
            }
        }
    }

    private func fetchArtistArtworkURL(artist: String) async -> URL? {
        do {
            let artists = try await AudiusService.shared.searchUsers(query: artist, limit: 1)
            if let first = artists.first {
                return first.profilePicture?.url480 ?? first.profilePicture?.url150 ?? first.profilePicture?.url1000
            }
        } catch {
            print("Failed to fetch artist artwork: \(error)")
        }
        return nil
    }

    private func performRemix(for pair: RemixArtistPair) {
        let playlist = [pair.track1, pair.track2].compactMap { item in
            PlayableTrackDTO(
                id: UUID(),
                title: item.title,
                artistName: item.artist,
                playbackUrl: item.playbackURL,
                playbackStoreID: item.id,
                isAIGenerated: false,
                duration: nil,
                fileUrl: nil,
                artworkURL: item.artworkURL
            )
        }

        guard !playlist.isEmpty else { return }
        let newPlayerState = PlayerReducer.State(playlist: playlist, currentIndex: 0)
        store.send(.tabBar(.setPlayerState(newPlayerState)))
    }

    private func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: "home.recentSearches") ?? []
    }

    private func saveRecentSearches(_ items: [String]) {
        UserDefaults.standard.set(items, forKey: "home.recentSearches")
    }

    private func addRecentSearch(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(10))
        saveRecentSearches(recentSearches)
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

struct SearchScreenView: View {
    @Binding var searchText: String
    let results: [MusicSearchResult]
    let isSearching: Bool
    let recentSearches: [String]
    let suggestedSearches: [String]
    let onClose: () -> Void
    let onChangeText: (String) -> Void
    let onSubmitSearch: (String) -> Void
    let onSelectRecent: (String) -> Void
    let onDeleteRecent: (String) -> Void
    let onClearRecent: () -> Void
    let onPlay: (MusicSearchResult) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button("취소") { onClose() }
                        .foregroundColor(.white)

                    TextField("노래/가수 검색하기", text: $searchText)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                        .onChange(of: searchText) { _, newValue in
                            onChangeText(newValue)
                        }
                        .onSubmit {
                            onSubmitSearch(searchText)
                        }
                }
                .padding()

                if isSearching {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if !results.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(results) { result in
                                MusicSearchResultView(result: result) {
                                    onPlay(result)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("최근 검색")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !recentSearches.isEmpty {
                                        Button("전체 삭제") {
                                            onClearRecent()
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal)

                                if recentSearches.isEmpty {
                                    Text("최근 검색어가 없습니다")
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(recentSearches, id: \.self) { item in
                                                HStack(spacing: 8) {
                                                    Button(action: { onSelectRecent(item) }) {
                                                        Text(item)
                                                            .foregroundColor(.white)
                                                            .lineLimit(1)
                                                    }
                                                    Button(action: { onDeleteRecent(item) }) {
                                                        Image(systemName: "xmark")
                                                            .font(.caption)
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                }
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 14)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("추천 검색어")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(suggestedSearches, id: \.self) { item in
                                            Button(action: {
                                                onSelectRecent(item)
                                            }) {
                                                Text(item)
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 10)
                                                    .padding(.horizontal, 14)
                                                    .background(Color.white.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    }
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.95), Color.pink.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .background(Color.white.opacity(0.03))
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isFocused = true
            }
        }
    }
}

struct HomeNavigationBarView: View {
    let store: StoreOf<AppReducer>
    @Binding var isLoggedIn: Bool
    var body: some View {
        NavigationLink(destination: SettingsView(store: store, isLoggedIn: $isLoggedIn)) {
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

            Text("Audius 트렌딩")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.65))
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

// MARK: - 플레이스홀더 뷰들
struct HitSongCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 110, height: 110)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(0.8)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(width: 80, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.15))
                .frame(width: 60, height: 14)
        }
        .frame(width: 130)
    }
}

struct RemixArtistPairPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                        .scaleEffect(0.8)
                )
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(width: 70, height: 16)
        }
    }
}
