//
//  MiniPlayerView.swift
//  BeamApp
//
//  Created by freed on 10/11/24.
//

import SwiftUI
import ComposableArchitecture
import MusicKit
import UniformTypeIdentifiers

struct MiniPlayerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    let store: Store<PlayerReducer.State, PlayerReducer.Action>
    @Binding var isPlayerViewVisible: Bool
    let albumArtNamespace: Namespace.ID
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { (viewStore: ViewStore<PlayerReducer.State, PlayerReducer.Action>) in
            miniPlayerContent(viewStore: viewStore)
        }
    }

    @ViewBuilder
    private func miniPlayerContent(viewStore: ViewStore<PlayerReducer.State, PlayerReducer.Action>) -> some View {
        let displayTitle = viewStore.currentTrack?.title ?? audioManager.currentTrackMetadata.title

        if let title = displayTitle, !title.isEmpty, title != "No Track" {
            let artist = viewStore.currentTrack?.artistName ?? audioManager.currentTrackMetadata.artist ?? "Unknown Artist"
            let progress = audioManager.duration > 0 ? audioManager.currentTime / audioManager.duration : 0

            VStack(spacing: 0) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    albumArtView
                    trackInfoView(title: title, artist: artist)
                    Spacer()
                    playPauseButton
                }
                .padding(AppTheme.Spacing.sm)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.white.opacity(0.12)
                        LinearGradient(
                            colors: [AppTheme.primaryAccent, AppTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.12)
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
            .padding(.horizontal, AppTheme.Spacing.md)
            .onTapGesture {
                isPlayerViewVisible = true
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Now playing \(title) by \(artist)")
            .accessibilityHint("Double tap to open the player")
        } else {
            EmptyView()
        }
    }

    private var albumArtView: some View {
        Group {
            if let albumArt = audioManager.currentTrackMetadata.albumArt {
                Image(uiImage: albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                    .shadow(color: AppTheme.primaryAccent.opacity(0.35), radius: 5, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    .frame(width: 52, height: 52)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
            }
        }
    }

    private func trackInfoView(title: String, artist: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(artist)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.68))
                .lineLimit(1)
        }
    }
    
    private var playPauseButton: some View {
        Button(action: {
            Task {
                await playPause()
            }
        }) {
            Image(systemName: audioManager.isPlayingMusic ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.primaryAccent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audioManager.isPlayingMusic ? "Pause" : "Play")
        .highPriorityGesture(
            TapGesture()
        )
    }
    
    private func playPause() async {
        if audioManager.isPlayingMusic {
            await audioManager.pause()
        } else {
            await audioManager.play()
        }
    }
}

@MainActor
final class AppleMusicPlaybackState: ObservableObject {
    static let shared = AppleMusicPlaybackState()

    @Published var currentSong: MusicSearchResult?
    @Published var isPlaying = false

    private init() {}

    func start(song: MusicSearchResult) {
        currentSong = song
        isPlaying = true
    }

    func stop() {
        ApplicationMusicPlayer.shared.stop()
        currentSong = nil
        isPlaying = false
    }
}

struct AppleMusicMiniPlayerView: View {
    @ObservedObject private var playbackState = AppleMusicPlaybackState.shared
    @Binding var isAppleMusicPlayerVisible: Bool

    var body: some View {
        if let song = playbackState.currentSong {
            VStack(spacing: 0) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    artworkView(for: song)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(song.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(song.artist)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.68))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: playbackState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.primaryAccent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(playbackState.isPlaying ? "Pause Apple Music" : "Play Apple Music")
                }
                .padding(AppTheme.Spacing.sm)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryAccent, AppTheme.secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.12)
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
            .padding(.horizontal, AppTheme.Spacing.md)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .onTapGesture {
                isAppleMusicPlayerVisible = true
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Apple Music now playing \(song.title) by \(song.artist)")
            .accessibilityHint("Double tap to open the Apple Music player")
        }
    }

    @ViewBuilder
    private func artworkView(for song: MusicSearchResult) -> some View {
        if let artworkURL = song.artworkURL {
            AsyncImage(url: artworkURL) { image in
                image.resizable()
                    .scaledToFill()
            } placeholder: {
                Color.white.opacity(0.14)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.62))
                }
                .frame(width: 52, height: 52)
        }
    }

    private func togglePlayback() {
        let player = ApplicationMusicPlayer.shared
        if playbackState.isPlaying {
            player.pause()
            playbackState.isPlaying = false
        } else {
            Task {
                do {
                    try await player.play()
                    playbackState.isPlaying = true
                } catch {
                    print("Failed to resume Apple Music playback: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct AppleMusicFullPlayerView: View {
    @ObservedObject private var playbackState = AppleMusicPlaybackState.shared
    @Binding var isPresented: Bool
    let onPlayConvertibleSource: (PlayableTrackDTO) -> Void
    @State private var showVoiceConversionUnavailable = false
    @State private var isResolvingConvertibleSource = false
    @State private var resolverMessage: String?
    @State private var isImportingAudioFile = false

    var body: some View {
        ZStack {
            BeamScreenBackground()

            if let song = playbackState.currentSong {
                VStack(spacing: AppTheme.Spacing.lg) {
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close player")

                        Spacer()

                        Text("Apple Music")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))

                        Spacer()

                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    artworkView(for: song)

                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text(song.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(song.artist)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)

                        Text("Playing with MusicKit")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xxs)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .padding(.top, AppTheme.Spacing.xs)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    HStack(spacing: AppTheme.Spacing.xl) {
                        Button {
                            togglePlayback()
                        } label: {
                            Image(systemName: playbackState.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 76, height: 76)
                                .background(AppTheme.primaryAccent, in: Circle())
                                .shadow(color: AppTheme.primaryAccent.opacity(0.35), radius: 18, x: 0, y: 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(playbackState.isPlaying ? "Pause Apple Music" : "Play Apple Music")
                    }
                    .padding(.top, AppTheme.Spacing.md)

                    Button {
                        if let song = playbackState.currentSong {
                            resolveConvertibleSource(for: song)
                        }
                    } label: {
                        Label(
                            isResolvingConvertibleSource ? "Finding convertible source..." : "Find convertible source",
                            systemImage: isResolvingConvertibleSource ? "hourglass" : "waveform.badge.magnifyingglass"
                        )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(AppTheme.primaryAccent.opacity(isResolvingConvertibleSource ? 0.36 : 0.92), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isResolvingConvertibleSource)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .accessibilityHint("Searches SoundCloud, Audius, and Jamendo for a playable track that can be converted")

                    Button {
                        isImportingAudioFile = true
                    } label: {
                        Label("Import audio file", systemImage: "folder.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.top, -AppTheme.Spacing.sm)
                    .accessibilityHint("Imports an audio file from Files for playback and voice conversion")

                    Button {
                        showVoiceConversionUnavailable = true
                    } label: {
                        Label("Why not direct MusicKit conversion?", systemImage: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -AppTheme.Spacing.xs)

                    Spacer()
                }
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
        }
        .alert("Voice conversion is not available", isPresented: $showVoiceConversionUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("MusicKit plays Apple Music streams directly and does not expose the raw audio file needed for conversion. Beam can look for a playable SoundCloud, Audius, or Jamendo source, or use an audio file you import.")
        }
        .alert("Convertible source", isPresented: Binding(
            get: { resolverMessage != nil },
            set: { if !$0 { resolverMessage = nil } }
        )) {
            Button("OK", role: .cancel) { resolverMessage = nil }
        } message: {
            Text(resolverMessage ?? "")
        }
        .fileImporter(
            isPresented: $isImportingAudioFile,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleImportedAudioFile(result)
        }
    }

    @ViewBuilder
    private func artworkView(for song: MusicSearchResult) -> some View {
        if let artworkURL = song.artworkURL {
            AsyncImage(url: artworkURL) { image in
                image.resizable()
                    .scaledToFill()
            } placeholder: {
                Color.white.opacity(0.12)
            }
            .frame(width: 312, height: 312)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 16)
        } else {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(width: 312, height: 312)
        }
    }

    private func togglePlayback() {
        let player = ApplicationMusicPlayer.shared
        if playbackState.isPlaying {
            player.pause()
            playbackState.isPlaying = false
        } else {
            Task {
                do {
                    try await player.play()
                    playbackState.isPlaying = true
                } catch {
                    print("Failed to resume Apple Music playback: \(error.localizedDescription)")
                }
            }
        }
    }

    private func resolveConvertibleSource(for song: MusicSearchResult) {
        isResolvingConvertibleSource = true
        Task {
            do {
                let resolvedTrack = try await ConvertibleAudioResolver.shared.resolve(song)
                await MainActor.run {
                    isResolvingConvertibleSource = false
                    isPresented = false
                    AppleMusicPlaybackState.shared.stop()
                    onPlayConvertibleSource(resolvedTrack)
                }
            } catch {
                await MainActor.run {
                    isResolvingConvertibleSource = false
                    resolverMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleImportedAudioFile(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            let importedURL = try AudioFileImportResolver.copyIntoAppStorage(selectedURL)
            let sourceSong = playbackState.currentSong
            let importedTrack = PlayableTrackDTO(
                id: UUID(),
                title: sourceSong?.title ?? importedURL.deletingPathExtension().lastPathComponent,
                artistName: sourceSong?.artist ?? "Imported Audio",
                playbackUrl: importedURL.absoluteString,
                playbackStoreID: "import-\(UUID().uuidString)",
                isAIGenerated: false,
                duration: nil,
                fileUrl: importedURL.absoluteString,
                artworkURL: sourceSong?.artworkURL
            )
            isPresented = false
            AppleMusicPlaybackState.shared.stop()
            onPlayConvertibleSource(importedTrack)
        } catch {
            resolverMessage = error.localizedDescription
        }
    }
}

enum ConvertibleSource: String {
    case soundCloud = "SoundCloud"
    case audius = "Audius"
    case jamendo = "Jamendo"
}

final class ConvertibleAudioResolver {
    static let shared = ConvertibleAudioResolver()

    private init() {}

    func resolve(_ song: MusicSearchResult) async throws -> PlayableTrackDTO {
        let query = "\(song.title) \(song.artist)"

        if let soundCloudResult = try? await SoundCloudService.shared.searchPlayableTrack(query: query, matching: song) {
            return soundCloudResult.toPlayableTrackDTO(source: .soundCloud)
        }

        if let audiusResult = try? await resolveAudius(song: song, query: query) {
            return audiusResult.toPlayableTrackDTO(source: .audius)
        }

        if let jamendoResult = try? await resolveJamendo(song: song, query: query) {
            return jamendoResult.toPlayableTrackDTO(source: .jamendo)
        }

        throw ConvertibleAudioResolverError.noConvertibleSource(song.title)
    }

    private func resolveAudius(song: MusicSearchResult, query: String) async throws -> MusicSearchResult? {
        let tracks = try await AudiusService.shared.searchTracks(query: query, limit: 12)
            .map { $0.toMusicSearchResult() }
            .filter { $0.playbackURL != nil }
        return bestMatch(in: tracks, for: song) ?? tracks.first
    }

    private func resolveJamendo(song: MusicSearchResult, query: String) async throws -> MusicSearchResult? {
        let tracks = try await JamendoService.shared.searchTracks(query: query, limit: 12)
            .map { $0.toMusicSearchResult() }
            .filter { $0.playbackURL != nil }
        return bestMatch(in: tracks, for: song) ?? tracks.first
    }

    private func bestMatch(in candidates: [MusicSearchResult], for song: MusicSearchResult) -> MusicSearchResult? {
        candidates
            .map { item in (candidate: item, score: matchScore(item, song)) }
            .filter { $0.score >= 2 }
            .sorted { $0.score > $1.score }
            .first?
            .candidate
    }

    private func matchScore(_ candidate: MusicSearchResult, _ target: MusicSearchResult) -> Int {
        let candidateTitle = normalized(candidate.title)
        let targetTitle = normalized(target.title)
        let candidateArtist = normalized(candidate.artist)
        let targetArtist = normalized(target.artist)

        var score = 0
        if candidateTitle == targetTitle { score += 4 }
        if candidateTitle.contains(targetTitle) || targetTitle.contains(candidateTitle) { score += 2 }
        if candidateArtist == targetArtist { score += 4 }
        if candidateArtist.contains(targetArtist) || targetArtist.contains(candidateArtist) { score += 2 }
        return score
    }
}

final class SoundCloudService {
    static let shared = SoundCloudService()

    private let baseURL = "https://api.soundcloud.com"

    private var clientID: String? {
        configuredValue(for: "SOUNDCLOUD_CLIENT_ID")
    }

    private var accessToken: String? {
        configuredValue(for: "SOUNDCLOUD_ACCESS_TOKEN")
    }

    private init() {}

    func searchPlayableTrack(query: String, matching song: MusicSearchResult) async throws -> MusicSearchResult? {
        guard let request = makeRequest(path: "/tracks", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "access", value: "playable"),
            URLQueryItem(name: "limit", value: "12")
        ]) else {
            throw SoundCloudError.notConfigured
        }

        let response = try await fetch(SoundCloudTracksResponse.self, request: request)
        let candidates = response.tracks.filter { $0.isPlayable }

        let best = candidates
            .map { (track: $0, score: matchScore($0, song)) }
            .filter { $0.score >= 2 }
            .sorted { $0.score > $1.score }
            .first?
            .track ?? candidates.first

        guard let best else { return nil }
        let streamURL = try await streamURL(for: best.id)
        return best.toMusicSearchResult(streamURL: streamURL)
    }

    private func streamURL(for trackID: Int) async throws -> String {
        guard let request = makeRequest(path: "/tracks/\(trackID)/streams", queryItems: []) else {
            throw SoundCloudError.notConfigured
        }

        let streams = try await fetch(SoundCloudStreamsResponse.self, request: request)
        guard let streamURL = streams.preferredStreamURL else {
            throw SoundCloudError.missingStreamURL
        }
        return streamURL
    }

    private func makeRequest(path: String, queryItems: [URLQueryItem]) -> URLRequest? {
        guard var components = URLComponents(string: baseURL + path) else { return nil }
        var items = queryItems

        if accessToken == nil, let clientID {
            items.append(URLQueryItem(name: "client_id", value: clientID))
        } else if accessToken == nil {
            return nil
        }

        components.queryItems = items.isEmpty ? nil : items
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        if let accessToken {
            request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func fetch<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SoundCloudError.serverError
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private func configuredValue(for key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty {
            return plistValue
        }

        return nil
    }

    private func matchScore(_ candidate: SoundCloudTrack, _ target: MusicSearchResult) -> Int {
        let candidateTitle = normalized(candidate.title)
        let targetTitle = normalized(target.title)
        let candidateArtist = normalized(candidate.user.username)
        let targetArtist = normalized(target.artist)

        var score = 0
        if candidateTitle == targetTitle { score += 4 }
        if candidateTitle.contains(targetTitle) || targetTitle.contains(candidateTitle) { score += 2 }
        if candidateArtist == targetArtist { score += 4 }
        if candidateArtist.contains(targetArtist) || targetArtist.contains(candidateArtist) { score += 2 }
        return score
    }
}

private struct SoundCloudTracksResponse: Decodable {
    let tracks: [SoundCloudTrack]

    init(from decoder: Decoder) throws {
        if let array = try? [SoundCloudTrack](from: decoder) {
            tracks = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        tracks = try container.decode([SoundCloudTrack].self, forKey: .collection)
    }

    private enum CodingKeys: String, CodingKey {
        case collection
    }
}

private struct SoundCloudTrack: Decodable {
    let id: Int
    let title: String
    let duration: Double?
    let artworkURL: URL?
    let access: String?
    let streamable: Bool?
    let user: SoundCloudUser

    var isPlayable: Bool {
        access == nil || access == "playable" || streamable == true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case duration
        case artworkURL = "artwork_url"
        case access
        case streamable
        case user
    }

    func toMusicSearchResult(streamURL: String) -> MusicSearchResult {
        MusicSearchResult(
            id: "soundcloud-\(id)",
            title: title,
            artist: user.username,
            artworkURL: artworkURL,
            isExplicit: false,
            playbackURL: streamURL,
            genre: nil
        )
    }
}

private struct SoundCloudUser: Decodable {
    let username: String
}

private struct SoundCloudStreamsResponse: Decodable {
    let streams: [String: String]

    var preferredStreamURL: String? {
        streams["http_mp3_128_url"]
        ?? streams["progressive_mp3_url"]
        ?? streams["hls_mp3_128_url"]
        ?? streams["hls_opus_64_url"]
        ?? streams.values.first
    }

    init(from decoder: Decoder) throws {
        streams = try [String: String](from: decoder)
    }
}

enum SoundCloudError: Error, LocalizedError {
    case notConfigured
    case serverError
    case missingStreamURL

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SoundCloud is not configured. Add SOUNDCLOUD_CLIENT_ID or SOUNDCLOUD_ACCESS_TOKEN, then try again."
        case .serverError:
            return "SoundCloud returned an error."
        case .missingStreamURL:
            return "SoundCloud did not return a playable stream URL."
        }
    }
}

enum ConvertibleAudioResolverError: Error, LocalizedError {
    case noConvertibleSource(String)

    var errorDescription: String? {
        switch self {
        case .noConvertibleSource(let title):
            return "No convertible full-track source was found for \(title). Try importing an audio file you own."
        }
    }
}

enum AudioFileImportResolver {
    static func copyIntoAppStorage(_ sourceURL: URL) throws -> URL {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let importsURL = documentsURL.appendingPathComponent("ImportedAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: importsURL, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let safeName = sourceURL.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let destinationURL = importsURL.appendingPathComponent("\(safeName)-\(UUID().uuidString).\(fileExtension)")
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}

private extension MusicSearchResult {
    func toPlayableTrackDTO(source: ConvertibleSource) -> PlayableTrackDTO {
        PlayableTrackDTO(
            id: UUID(),
            title: title,
            artistName: artist,
            playbackUrl: playbackURL,
            playbackStoreID: "\(source.rawValue.lowercased())-\(id)",
            isAIGenerated: false,
            duration: nil,
            fileUrl: nil,
            artworkURL: artworkURL
        )
    }
}

private func normalized(_ text: String) -> String {
    text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}
