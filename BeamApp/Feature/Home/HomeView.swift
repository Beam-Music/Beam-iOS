//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import MusicKit

// MARK: - AI Convert Helper Functions
func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
    Task {
        do {
            let audioData = try Data(contentsOf: fileURL)
            let convertedAudioData = try await voiceConversionService.convert(
                audioData: audioData,
                voiceId: "dionn_v1_singing",
                voiceType: "singer",
                trimStart: 0,
                trimDuration: 60
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

private struct AppleMusicChartResponse: Decodable {
    let feed: Feed

    struct Feed: Decodable {
        let results: [Song]
    }

    struct Song: Decodable {
        let artistName: String
        let id: String
        let name: String
        let artworkUrl100: String?
        let contentAdvisoryRating: String?
        let genres: [Genre]?

        struct Genre: Decodable {
            let name: String
        }

        var musicSearchResult: MusicSearchResult {
            let artwork = artworkUrl100?
                .replacingOccurrences(of: "100x100bb", with: "600x600bb")

            return MusicSearchResult(
                id: "apple-\(id)",
                title: name,
                artist: artistName,
                artworkURL: artwork.flatMap(URL.init(string:)),
                isExplicit: contentAdvisoryRating?.lowercased().contains("explicit") == true
                    || contentAdvisoryRating?.lowercased().contains("explict") == true,
                playbackURL: nil,
                genre: genres?.first?.name
            )
        }
    }
}

private enum AppleMusicChartService {
    static func fetchTrendingSongs(limit: Int = 25) async throws -> [MusicSearchResult] {
        guard let url = URL(string: "https://rss.applemarketingtools.com/api/v2/us/music/most-played/\(limit)/songs.json") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }

        let songs = try JSONDecoder()
            .decode(AppleMusicChartResponse.self, from: data)
            .feed
            .results
            .map(\.musicSearchResult)

        return await songsWithPreviewURLs(songs)
    }

    private static func songsWithPreviewURLs(_ songs: [MusicSearchResult]) async -> [MusicSearchResult] {
        await withTaskGroup(of: (Int, MusicSearchResult).self) { group in
            for (index, song) in songs.enumerated() {
                group.addTask {
                    let previewURL = await fetchITunesPreviewURL(for: song)
                    return (
                        index,
                        MusicSearchResult(
                            id: song.id,
                            title: song.title,
                            artist: song.artist,
                            artworkURL: song.artworkURL,
                            isExplicit: song.isExplicit,
                            playbackURL: previewURL,
                            genre: song.genre
                        )
                    )
                }
            }

            var indexedSongs: [(Int, MusicSearchResult)] = []
            for await indexedSong in group {
                indexedSongs.append(indexedSong)
            }
            return indexedSongs
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }

    private static func fetchITunesPreviewURL(for song: MusicSearchResult) async -> String? {
        let appleID = song.id.replacingOccurrences(of: "apple-", with: "")
        if let previewURL = await fetchITunesPreviewURL(lookupID: appleID, matching: song) {
            return previewURL
        }
        return await searchITunesPreviewURL(for: song)
    }

    private static func fetchITunesPreviewURL(lookupID: String, matching song: MusicSearchResult) async -> String? {
        guard var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "id", value: lookupID),
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "entity", value: "song")
        ]
        return await fetchITunesPreviewURL(from: components, matching: song)
    }

    private static func searchITunesPreviewURL(for song: MusicSearchResult) async -> String? {
        guard var components = URLComponents(string: "https://itunes.apple.com/search") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(song.title) \(song.artist)"),
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5")
        ]
        return await fetchITunesPreviewURL(from: components, matching: song)
    }

    private static func fetchITunesPreviewURL(from components: URLComponents, matching song: MusicSearchResult) async -> String? {
        guard let url = components.url else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let searchResponse = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            let normalizedTitle = normalized(song.title)
            let normalizedArtist = normalized(song.artist)

            return searchResponse.results.first(where: {
                normalized($0.trackName) == normalizedTitle
                && normalized($0.artistName).contains(normalizedArtist)
            })?.previewUrl
            ?? searchResponse.results.first(where: {
                normalized($0.trackName) == normalizedTitle
            })?.previewUrl
            ?? searchResponse.results.first?.previewUrl
        } catch {
            print("Failed to fetch Apple Music preview URL for \(song.title): \(error)")
            return nil
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private struct ITunesSearchResponse: Decodable {
        let results: [Track]

        struct Track: Decodable {
            let artistName: String
            let trackName: String
            let previewUrl: String?
        }
    }
}

@MainActor
private enum AppleMusicPlaybackService {
    static func playFullTrack(_ song: MusicSearchResult) async throws {
        let authorizationStatus = MusicAuthorization.currentStatus == .authorized
            ? MusicAuthorization.currentStatus
            : await MusicAuthorization.request()

        guard authorizationStatus == .authorized else {
            throw PlayerError.musicAuthorizationFailed
        }

        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else {
            throw PlayerError.noMusicSubscription
        }

        let catalogID = song.id.replacingOccurrences(of: "apple-", with: "")
        var request = MusicCatalogResourceRequest<MusicKit.Song>(
            matching: \.id,
            equalTo: MusicItemID(catalogID)
        )
        request.limit = 1

        guard let catalogSong = try await request.response().items.first else {
            throw PlayerError.trackNotFound(song.title)
        }

        await AudioManager.shared.stop()
        let player = ApplicationMusicPlayer.shared
        player.queue = ApplicationMusicPlayer.Queue(for: [catalogSong])
        try await player.play()
        AppleMusicPlaybackState.shared.start(song: song)
    }

    static func stop() {
        ApplicationMusicPlayer.shared.stop()
        AppleMusicPlaybackState.shared.stop()
    }
}

// MARK: - Music Search Result View
struct MusicSearchResultView: View {
    let result: MusicSearchResult
    let onPlay: () -> Void
    let onConvert: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Group {
                if let artworkURL = result.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.10)
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.10))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text(result.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
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
                    .foregroundColor(.white.opacity(0.68))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let onConvert {
                Button(action: onConvert) {
                    Image(systemName: "waveform")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }
            }
            
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primaryAccent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(result.title)")
        }
        .padding(AppTheme.Spacing.md)
        .beamCard(cornerRadius: AppTheme.Radius.md, fillOpacity: 0.08)
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
    @State private var appleMusicTrendingSongs: [MusicSearchResult] = []
    @State private var hitSongs: [MusicSearchResult] = []
    @State private var remixArtistPairs: [RemixArtistPair] = []
    @State private var songToAddToPlaylist: MusicSearchResult? = nil
    @State private var isPlaylistSelectSheetPresented: Bool = false
    @State private var isLoadingAppleMusicTrending: Bool = true
    @State private var isLoadingHitSongs: Bool = true
    @State private var isLoadingRemixPairs: Bool = true
    @State private var isRemixingDemo = false
    @State private var showAllAppleMusicSongsSheet = false
    @State private var showAllAppleMusicPreviewSongsSheet = false
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
            BeamScreenBackground()

            // Animated star field background
            StarFieldView(starCount: 28, scrollOffset: scrollOffset)
                .opacity(0.42)
            
            VStack(spacing: 0) {
                // Search bar
                Button(action: {
                    searchDraft = viewStore.searchText
                    showSearchScreen = true
                }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                        Text(viewStore.searchText.isEmpty ? "Search songs or artists" : viewStore.searchText)
                            .foregroundColor(viewStore.searchText.isEmpty ? .white.opacity(0.35) : .white)
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                    }
                    .frame(minHeight: 48)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.08)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search songs or artists")
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)

                if isConvertingFromSearch {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text(conversionStatusText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.orange.opacity(0.3))
                    .cornerRadius(20)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        BeamSectionHeader(
                            title: "Apple Music",
                            subtitle: "Full-track playback with MusicKit",
                            actionTitle: "View All",
                            action: { showAllAppleMusicSongsSheet = true }
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                if isLoadingAppleMusicTrending {
                                    ForEach(0..<5, id: \.self) { _ in
                                        HitSongCardPlaceholder()
                                    }
                                } else {
                                    ForEach(appleMusicTrendingSongs.indices, id: \.self) { idx in
                                        let song = appleMusicTrendingSongs[idx]
                                        HitSongCardView(
                                            song: song,
                                            sourceLabel: "MusicKit",
                                            onPlay: {
                                                playAppleMusicFullSong(song)
                                            },
                                            onAdd: {
                                                songToAddToPlaylist = song
                                                isPlaylistSelectSheetPresented = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        }
                        .frame(height: 180)

                        BeamSectionHeader(
                            title: "Apple Music Preview",
                            subtitle: "30-second previewUrl playback",
                            actionTitle: "View All",
                            action: { showAllAppleMusicPreviewSongsSheet = true }
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                if isLoadingAppleMusicTrending {
                                    ForEach(0..<5, id: \.self) { _ in
                                        HitSongCardPlaceholder()
                                    }
                                } else {
                                    ForEach(appleMusicTrendingSongs.indices, id: \.self) { idx in
                                        let song = appleMusicTrendingSongs[idx]
                                        HitSongCardView(
                                            song: song,
                                            sourceLabel: "Preview",
                                            onPlay: {
                                                playAppleMusicPreviewSong(song)
                                            },
                                            onAdd: {
                                                songToAddToPlaylist = song
                                                isPlaylistSelectSheetPresented = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        }
                        .frame(height: 180)

                        BeamSectionHeader(
                            title: "Audius",
                            subtitle: "Playable popular songs for voice conversion tests",
                            actionTitle: "View All",
                            action: { showAllHitSongsSheet = true }
                        )

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                if isLoadingHitSongs {
                                    // Placeholder while loading
                                    ForEach(0..<5, id: \.self) { _ in
                                        HitSongCardPlaceholder()
                                    }
                                } else {
                                    ForEach(hitSongs.indices, id: \.self) { idx in
                                        let song = hitSongs[idx]
                                        HitSongCardView(
                                            song: song,
                                            sourceLabel: "Audius",
                                            onPlay: {
                                                playAudiusSong(song)
                                            },
                                            onAdd: {
                                                songToAddToPlaylist = song
                                                isPlaylistSelectSheetPresented = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.lg)
                        }
                        .frame(height: 180) // 고정된 높이 설정
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                    .padding(.bottom, 104)
                    
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
                async let appleMusic: Void = fetchAppleMusicTrendingSongs()
                async let audiusMusic: Void = fetchTrendingSongs()
                _ = await (appleMusic, audiusMusic)
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
                },
                onConvert: { result, voice in
                    showSearchScreen = false
                    Task {
                        await convertSearchResult(result, voice: voice)
                    }
                }
            )
        }
        .sheet(isPresented: $showAllHitSongsSheet) {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(hitSongs) { song in
                            MusicSearchResultView(result: song, onPlay: {
                                showAllHitSongsSheet = false
                                playAudiusSong(song)
                            }, onConvert: nil)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background { BeamScreenBackground() }
                .navigationTitle("Audius Popular Music")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showAllAppleMusicSongsSheet) {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appleMusicTrendingSongs) { song in
                            MusicSearchResultView(result: song, onPlay: {
                                showAllAppleMusicSongsSheet = false
                                playAppleMusicFullSong(song)
                            }, onConvert: nil)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background { BeamScreenBackground() }
                .navigationTitle("Apple Music")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showAllAppleMusicPreviewSongsSheet) {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appleMusicTrendingSongs) { song in
                            MusicSearchResultView(result: song, onPlay: {
                                showAllAppleMusicPreviewSongsSheet = false
                                playAppleMusicPreviewSong(song)
                            }, onConvert: nil)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .background { BeamScreenBackground() }
                .navigationTitle("Apple Music Preview")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @State private var isConvertingFromSearch = false
    @State private var conversionStatusText = ""

    private func convertSearchResult(_ result: MusicSearchResult, voice: VoiceInfo) async {
        guard let playbackURLString = result.playbackURL, let playbackURL = URL(string: playbackURLString) else {
            return
        }

        await MainActor.run {
            isConvertingFromSearch = true
            conversionStatusText = "Downloading audio..."
        }

        do {
            let (audioData, _) = try await URLSession.shared.data(from: playbackURL)

            await MainActor.run {
                conversionStatusText = "Converting with \(voice.name)..."
            }

            let isSingerVoice = voice.id.contains("_singer") || voice.voiceType == "singer"
            let resolvedVoiceType = isSingerVoice ? "singer" : (voice.voiceType ?? "default")

            guard let provider = voiceConversionService as? BeamSVCVoiceConversionProvider else {
                throw NSError(domain: "VoiceConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Voice conversion service unavailable"])
            }

            let job = try await provider.submitAsyncJob(
                audioData: audioData,
                voiceId: voice.id,
                voiceType: resolvedVoiceType
            )

            await MainActor.run {
                conversionStatusText = "Converting full song... (Job: \(job.jobId.prefix(8)))"
            }

            let convertedData = try await provider.pollJobUntilFinished(jobId: job.jobId) { progress, stage in
                Task { @MainActor in
                    if let stage {
                        conversionStatusText = stage
                    } else {
                        conversionStatusText = "Conversion in progress... \(progress)%"
                    }
                }
            }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let safeTitle = result.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let safeVoice = voice.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let fileName = "voice_converted_\(safeTitle)_\(safeVoice)_\(Int(Date().timeIntervalSince1970)).mp3"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            try convertedData.write(to: fileURL)

            _ = try? ConvertedVoiceTrackStore.save(
                title: result.title,
                artistName: result.artist,
                voiceId: voice.id,
                voiceName: voice.name,
                filePath: fileURL.path,
                artworkURL: result.artworkURL
            )

            await MainActor.run {
                isConvertingFromSearch = false
                conversionStatusText = ""
            }

        } catch {
            await MainActor.run {
                isConvertingFromSearch = false
                conversionStatusText = ""
            }
            print("❌ Search voice conversion failed: \(error)")
        }
    }

    private func playAppleMusicFullSong(_ song: MusicSearchResult) {
        isSearchFieldFocused = false
        Task {
            do {
                try await AppleMusicPlaybackService.playFullTrack(song)
                await MainActor.run {
                    isMiniPlayerVisible = true
                }
            } catch {
                print("Failed to play Apple Music full track: \(error.localizedDescription)")
            }
        }
    }

    private func playAppleMusicPreviewSong(_ song: MusicSearchResult) {
        isSearchFieldFocused = false
        guard song.playbackURL != nil else {
            print("Apple Music preview URL is missing for: \(song.title)")
            return
        }

        AppleMusicPlaybackService.stop()
        viewStore.send(.playMusic(song))
        isMiniPlayerVisible = true
    }

    private func playAudiusSong(_ song: MusicSearchResult) {
        isSearchFieldFocused = false
        AppleMusicPlaybackService.stop()
        viewStore.send(.playMusic(song))
        isMiniPlayerVisible = true
    }

    // Audius 인기  songs 불러오기
    private func fetchAppleMusicTrendingSongs() async {
        do {
            let songs = try await AppleMusicChartService.fetchTrendingSongs(limit: 25)

            await MainActor.run {
                self.appleMusicTrendingSongs = Array(songs.prefix(20))
                self.isLoadingAppleMusicTrending = false
            }
        } catch {
            print("Failed to fetch Apple Music trending songs: \(error)")
            await MainActor.run {
                self.isLoadingAppleMusicTrending = false
            }
        }
    }

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
                        Text("Preview")
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

    // Build pop artist pairs that can actually be played from Audius.
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
        PlaylistSummaryDTO(id: UUID(), name: "Favorite Songs"),
        PlaylistSummaryDTO(id: UUID(), name: "Drive Music", user: PlaylistSummaryDTO.User(id: UUID(), username: "User")),
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
    let onConvert: (MusicSearchResult, VoiceInfo) -> Void
    @FocusState private var isFocused: Bool
    @State private var showVoiceSheet = false
    @State private var selectedResult: MusicSearchResult?
    @StateObject private var preConversionManager = PreConversionManager.shared
    @State private var availableVoices: [VoiceInfo] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close search")

                    TextField("Search songs or artists", text: $searchText)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .foregroundColor(.white)
                        .frame(minHeight: 48)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.08)
                        .onChange(of: searchText) { _, newValue in
                            onChangeText(newValue)
                        }
                        .onSubmit {
                            onSubmitSearch(searchText)
                        }
                }
                .padding(AppTheme.Spacing.md)

                if isSearching {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if !results.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(results) { result in
                                MusicSearchResultView(result: result, onPlay: {
                                    onPlay(result)
                                }, onConvert: {
                                    selectedResult = result
                                    Task {
                                        let voices = preConversionManager.availableVoices
                                        if voices.isEmpty {
                                            await preConversionManager.loadAvailableVoices()
                                        }
                                        availableVoices = preConversionManager.availableVoices
                                        showVoiceSheet = true
                                    }
                                })
                                .padding(.horizontal, AppTheme.Spacing.lg)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.md)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                HStack {
                                    Text("Recent Searches")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !recentSearches.isEmpty {
                                        Button("Clear All") {
                                            onClearRecent()
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, AppTheme.Spacing.lg)

                                if recentSearches.isEmpty {
                                    Text("No recent searches")
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, AppTheme.Spacing.lg)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: AppTheme.Spacing.xs) {
                                            ForEach(recentSearches, id: \.self) { item in
                                                HStack(spacing: AppTheme.Spacing.xs) {
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
                                                .padding(.horizontal, AppTheme.Spacing.sm)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, AppTheme.Spacing.lg)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text("Suggested Searches")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppTheme.Spacing.lg)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppTheme.Spacing.xs) {
                                        ForEach(suggestedSearches, id: \.self) { item in
                                            Button(action: {
                                                onSelectRecent(item)
                                            }) {
                                                Text(item)
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 10)
                                                    .padding(.horizontal, AppTheme.Spacing.sm)
                                                    .background(Color.white.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    .padding(.horizontal, AppTheme.Spacing.lg)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppTheme.Spacing.sm)
                    }
                }
            }
            .background { BeamScreenBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isFocused = true
            }
            .sheet(isPresented: $showVoiceSheet) {
                VoiceSelectionSheet(
                    voices: availableVoices,
                    onVoiceSelected: { voice in
                        showVoiceSheet = false
                        if let result = selectedResult {
                            onConvert(result, voice)
                        }
                    },
                    onCancel: { showVoiceSheet = false }
                )
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
    var sourceLabel: String = "Audius Trending"
    let onPlay: () -> Void
    let onAdd: () -> Void
    @State private var fetchedArtworkURL: URL? = nil
    @State private var isFetching: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            ZStack(alignment: .bottomTrailing) {
                if let url = song.artworkURL ?? fetchedArtworkURL {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.10)
                    }
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                } else if isFetching {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 128, height: 128)
                } else {
                    ZStack {
                        Color.white.opacity(0.10)
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                }
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .background(Color.black.opacity(0.32), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(AppTheme.Spacing.xs)
                .accessibilityLabel("Play \(song.title)")
            }
            Text(song.title)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(song.artist)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.68))
                .lineLimit(1)

            Text(sourceLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.70))
                .lineLimit(1)
                .padding(.horizontal, AppTheme.Spacing.xs)
                .padding(.vertical, AppTheme.Spacing.xxs)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
        .frame(width: 144, alignment: .leading)
        .padding(AppTheme.Spacing.xs)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
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

// MARK: - Placeholder Views
struct HitSongCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 128, height: 128)
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
        .frame(width: 144)
        .padding(AppTheme.Spacing.xs)
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
