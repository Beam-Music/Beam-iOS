//
//  MiniPlayerView.swift
//  BeamApp
//
//  Created by freed on 10/11/24.
//

import SwiftUI
import ComposableArchitecture
import MusicKit

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
    @State private var showVoiceConversionUnavailable = false

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
                        showVoiceConversionUnavailable = true
                    } label: {
                        Label("Voice conversion unavailable", systemImage: "waveform.badge.exclamationmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .accessibilityHint("Explains why Apple Music full tracks cannot be converted")

                    Spacer()
                }
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
        }
        .alert("Voice conversion is not available", isPresented: $showVoiceConversionUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("MusicKit plays Apple Music streams directly and does not expose the raw audio file needed for conversion. Use Apple Music Preview, Audius, or an imported audio file for voice conversion.")
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
}
