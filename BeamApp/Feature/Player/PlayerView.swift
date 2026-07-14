//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Album Art View
struct AlbumArtView: View {
    let albumArt: UIImage?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let albumArt = albumArt {
            Image(uiImage: albumArt)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 320, height: 320)
                .cornerRadius(24)
                .shadow(radius: 14)
        } else {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 320, height: 320)
                .cornerRadius(24)
        }
    }
}

// MARK: - Player Controls
struct PlayerControlsView: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack(spacing: 56) {
            ZStack {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Circle()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 8, height: 8)
                    .offset(x: 22, y: 10)
            }
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            ZStack {
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Circle()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 8, height: 8)
                    .offset(x: -22, y: 10)
            }
        }
    }
}

// MARK: - Custom Remix/AI Toggle (Figma style)
struct RemixAIToggle: View {
    @Binding var isAIVersion: Bool
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let circleSize = height * 0.8
            let circleOffset = isAIVersion ? width - circleSize - 4 : 4
            
            ZStack {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .offset(x: circleOffset - width / 2 + circleSize / 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAIVersion)
                HStack {
                    Text("REMIX")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAIVersion ? .white.opacity(0.5) : .white)
                        .animation(.easeInOut(duration: 0.2), value: isAIVersion)
                    
                    Spacer()
                    
                    Text("AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAIVersion ? .white : .white.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: isAIVersion)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: 120, height: 32)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAIVersion.toggle()
            }
        }
    }
}

struct Artist {
    let id: UUID = UUID()
    let name: String
    let imageName: String 
}

@MainActor
struct PlayerView: View {
    let store: Store<PlayerReducer.State, PlayerReducer.Action>
    @Binding var isMiniPlayerVisible: Bool
    let libraryStore: StoreOf<LibraryReducer>
    let albumArtNamespace: Namespace.ID
    @State private var isDetailViewPresented = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var isRemixSheetPresented = false
    @State private var selectedArtists: [Artist] = []
    @State private var isAddToPlaylistSheetPresented = false
    @State private var isPlaylistSelectSheetPresented = false
    @State private var showAddSuccess = false
    let mockArtists: [Artist] = [
        Artist(name: "Dua Lipa", imageName: "artist_dualipa"),
        Artist(name: "BlackPink", imageName: "artist_blackpink"),
        Artist(name: "H.E.R", imageName: "artist_her"),
        Artist(name: "Rihanna", imageName: "artist_rihanna")
    ]
    
    @State private var showIMSLPList = false 
    @State private var isRemixing = false
    @State private var remixedAudioURL: URL? = nil
    @State private var isAIVersion: Bool = false
    @State private var showNoMatchAlert = false
    
    @StateObject private var preConversionManager = PreConversionManager.shared
    @State private var isVoiceConverting = false
    @State private var showVoiceSelectionSheet = false
    @State private var availableVoices: [VoiceInfo] = []
    @State private var selectedVoice: VoiceInfo?
    @State private var voiceSelectionMode: VoiceSelectionMode = .preview
    @State private var showVoiceConversionError = false
    @State private var voiceConversionErrorMessage = ""
    @State private var voiceConversionStatusTitle = "Converting voice..."
    @State private var voiceConversionStatusSubtitle = "Preparing the preview segment"
    @State private var voiceConversionTask: Task<Void, Never>?
    @State private var isFullTrackConversionInProgress = false
    @State private var fullTrackJobProgress: Int = 0
    @State private var fullTrackJobStage: String?
    @State private var isScrubbing = false
    @State private var trackID: UUID? = nil
    @State private var localConvertedVoiceTracks: [ConvertedVoiceTrackRecord] = []
    
    enum VoiceSelectionMode {
        case preview
        case preconvert
    }

    private struct ReadyVoiceItem: Identifiable, Equatable {
        let id: String
        let voiceId: String?
        let voiceName: String
        let status: PreConversionJobStatus
        let track: PlayableTrackDTO?
        let updatedAt: Date

        var isReady: Bool {
            status == .completed && track != nil
        }
    }

    struct ViewState: Equatable {
        let isPlaying: Bool
        let isAIMusicEnabled: Bool
        let currentTrack: PlayableTrackDTO?
        let playlist: [PlayableTrackDTO]
        let currentIndex: Int
        
        init(state: PlayerReducer.State) {
            self.isPlaying = state.isPlaying
            self.isAIMusicEnabled = state.isAIMusicEnabled
            self.currentTrack = state.currentTrack
            self.playlist = state.playlist
            self.currentIndex = state.currentIndex
        }
    }
    
    var combinedArtistLabel: String {
        let base = audioManager.currentTrackMetadata.artist ?? ""
        let baseArtists = base.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        let remixNames = selectedArtists.map { $0.name }
        let all = (baseArtists + remixNames).filter { !$0.isEmpty }
        let unique = Array(NSOrderedSet(array: all)) as? [String] ?? all
        return unique.joined(separator: " + ")
    }
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
            ZStack {
                Color(hex: "#63477C")
                    .ignoresSafeArea()
                LinearGradient(
                    gradient: Gradient(colors: [Color.red.opacity(0.2), Color.purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let track = viewStore.currentTrack {
                        if let artworkURL = track.artworkURL {
                            AsyncImage(url: artworkURL) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 320, height: 320)
                            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                            .cornerRadius(24)
                            .shadow(radius: 14)
                            .padding(.bottom, 8)
                            .id(viewStore.currentTrack?.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            AlbumArtView(albumArt: audioManager.currentTrackMetadata.albumArt)
                                .frame(width: 320, height: 320)
                                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                                .cornerRadius(24)
                                .shadow(radius: 14)
                                .padding(.bottom, 8)
                                .id(viewStore.currentTrack?.id)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        VStack(spacing: 2) {
                            HStack(alignment: .center) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {/* TODO: Like */}) {
                                    Image(systemName: "heart")
                                        .foregroundColor(.white)
                                }
                                Button(action: { isPlaylistSelectSheetPresented = true }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal)
                            Text(track.artistName ?? "")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                        .id(viewStore.currentTrack?.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        AlbumArtView(albumArt: nil)
                            .frame(width: 320, height: 320)
                            .cornerRadius(24)
                            .shadow(radius: 14)
                            .padding(.bottom, 8)
                        VStack(spacing: 2) {
                            HStack(alignment: .center) {
                                Text("Loading...")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal)
                            Text("")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    }
                    
                    VStack(spacing: 0) {
                        if audioManager.duration > 0 {
                            SeekBar(
                                value: Binding(
                                    get: { audioManager.currentTime },
                                    set: { newValue in
                                        audioManager.currentTime = newValue
                                    }
                                ),
                                duration: audioManager.duration,
                                isScrubbing: isScrubbing,
                                onEditingChanged: { editing in
                                    isScrubbing = editing
                                },
                                onSeek: { target in
                                    Task {
                                        await audioManager.seek(to: target)
                                    }
                                }
                            )
                        } else {
                            SeekBar(
                                value: .constant(0),
                                duration: 1,
                                isEnabled: false,
                                onEditingChanged: { _ in },
                                onSeek: { _ in }
                            )
                        }
                        HStack {
                            Text(formatTime(audioManager.currentTime))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 18) {
                            Button(action: {
                                voiceSelectionMode = .preview
                                Task {
                                    await loadAvailableVoices()
                                    await MainActor.run {
                                        showVoiceSelectionSheet = true
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.wave.2")
                                    Text("Voice")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                        .background(AppTheme.voiceButtonFill.cornerRadius(24))
                                )
                            }
                        }
                        if let currentTrack = viewStore.currentTrack {
                            let items = readyVoiceItems(for: currentTrack)
                            if !items.isEmpty {
                                readyVoicesSection(items: items, viewStore: viewStore)
                            }
                        }
                    }
                    .padding(.bottom, 28)
                    
                    PlayerControlsView(
                        isPlaying: viewStore.isPlaying,
                        onPrevious: { viewStore.send(.previousTrack) },
                        onPlayPause: { viewStore.send(.playPause) },
                        onNext: { viewStore.send(.nextTrack) }
                    )
                    .padding(.top, 18)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.3), value: viewStore.currentTrack?.id)
                
                if isRemixing {
                    ProgressView("AI converting/remixing...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
                
                if isVoiceConverting {
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()
                            Button(action: cancelVoiceConversion) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(0.14))
                                    .clipShape(Circle())
                            }
                        }
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(voiceConversionStatusTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(voiceConversionStatusSubtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        if isFullTrackConversionInProgress {
                            Text("The preview plays first, then switches automatically when the full track is ready")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .zIndex(100)
                }
            }
            .onAppear {
                viewStore.send(.syncPlaybackState)
                if !viewStore.isPlaying {
                    viewStore.send(.playPause)
                }
                libraryStore.send(.fetchUserPlaylists)
                localConvertedVoiceTracks = ConvertedVoiceTrackStore.load()
            }
            .onChange(of: viewStore.currentTrack?.id) { _, newTrackID in
                guard newTrackID != nil, let currentTrack = viewStore.currentTrack else { return }
                Task {
                    await preConversionManager.warmup(track: currentTrack)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
                // When preview ends, fall back to the original track if the full track is still being prepared
                if isFullTrackConversionInProgress {
                    if let originalTrack = viewStore.currentTrack {
                        let fallbackTitle = originalTrack.title
                        let fallbackArtist = originalTrack.artistName ?? "Unknown Artist"
                        Task {
                            if let urlString = originalTrack.playbackUrl ?? originalTrack.fileUrl {
                                try? await audioManager.playAIMusic(
                                    from: urlString,
                                    title: fallbackTitle,
                                    artist: fallbackArtist,
                                    artworkURL: originalTrack.artworkURL
                                )
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isPlaylistSelectSheetPresented, onDismiss: {
                libraryStore.send(.fetchUserPlaylists)
            }) {
                let playlists = ViewStore(libraryStore, observe: { $0.playlists }).state
                if let track = viewStore.currentTrack {
                }
            }
            .alert("Added to playlist!", isPresented: $showAddSuccess) {
                Button("OK", role: .cancel) { showAddSuccess = false }
            }
            
            .alert("Could not find a public-domain song.", isPresented: $showNoMatchAlert) {
                Button("OK", role: .cancel) { showNoMatchAlert = false }
            }
            
            .alert("Voice Conversion Failed", isPresented: $showVoiceConversionError) {
                Button("OK", role: .cancel) { showVoiceConversionError = false }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .sheet(isPresented: $showVoiceSelectionSheet) {
                VoiceSelectionSheet(
                    voices: preConversionManager.availableVoices.count >= availableVoices.count ? preConversionManager.availableVoices : availableVoices,
                    onVoiceSelected: { voice in
                        selectedVoice = voice
                        preConversionManager.setPreferredVoice(voice)
                        showVoiceSelectionSheet = false
                        switch voiceSelectionMode {
                        case .preview:
                            let trackTitle = viewStore.currentTrack?.title ?? "Unknown"
                            TTFATelemetry.shared.recordVoiceTap(trackTitle: trackTitle, voiceId: voice.id)
                            performVoiceConversion(with: voice)
                        case .preconvert:
                            guard let track = viewStore.currentTrack else {
                                showVoiceConversionError = true
                                voiceConversionErrorMessage = "No song is currently playing."
                                return
                            }
                            Task {
                                await preConversionManager.enqueue(track: track, voice: voice)
                                if let error = preConversionManager.lastErrorMessage {
                                    await MainActor.run {
                                        showVoiceConversionError = true
                                        voiceConversionErrorMessage = error
                                    }
                                }
                            }
                        }
                    },
                    onCancel: {
                        showVoiceSelectionSheet = false
                    },
                    currentTrack: viewStore.currentTrack,
                    preConversionManager: preConversionManager
                )
            }
            .sheet(isPresented: $isAddToPlaylistSheetPresented) {
                AddToPlaylistSheet(
                    playlist: PlaylistSummaryDTO(
                        id: UUID(),
                        name: "Current Track",
                        user: nil
                    ),
                    onAdd: { _ in
                        isAddToPlaylistSheetPresented = false
                    }
                )
            }
            .alert("Voice Conversion Error", isPresented: $showVoiceConversionError) {
                Button("OK") { }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .overlay(
                ZStack(alignment: .top) {
                    // Full-screen overlay: waiting for preview conversion
                    if isVoiceConverting {
                        VStack(spacing: 20) {
                            HStack {
                                Spacer()
                                Button(action: cancelVoiceConversion) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.14))
                                        .clipShape(Circle())
                                }
                                .padding(.top, 24)
                                .padding(.trailing, 24)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 80, height: 80)
                                ProgressView()
                                    .scaleEffect(1.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            VStack(spacing: 6) {
                                Text(voiceConversionStatusTitle)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                Text(voiceConversionStatusSubtitle)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.78).ignoresSafeArea())
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    }

                    // Top banner: when the full song is converting in the background (preview is playing)
                    if !isVoiceConverting && isFullTrackConversionInProgress {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text("Converting full song...")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    if fullTrackJobProgress > 0 {
                                        Text("\(fullTrackJobProgress)%")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                if let stage = fullTrackJobStage {
                                    Text(stage)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.75))
                                } else {
                                    Text("Preparing a high-quality version in the background")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.conversionBannerStart, AppTheme.conversionBannerEnd],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFullTrackConversionInProgress)
                    }
                }
            )
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func statusColor(for track: PlayableTrackDTO) -> Color {
        if let record = preConversionManager.latestJob(for: track) {
            switch record.status {
            case .completed: return .green
            case .converting, .queued: return .orange
            case .failed: return .red
            }
        }
        if preConversionManager.latestConvertedTrack(for: track) != nil {
            return .green
        }
        return .gray
    }

    private func readyVoiceItems(for track: PlayableTrackDTO) -> [ReadyVoiceItem] {
        var items: [ReadyVoiceItem] = []
        let voices = preConversionManager.availableVoices.isEmpty ? availableVoices : preConversionManager.availableVoices

        for voice in voices {
            if let convertedTrack = preConversionManager.latestConvertedTrack(for: track, voiceId: voice.id) {
                items.append(
                    ReadyVoiceItem(
                        id: "server-\(voice.id)",
                        voiceId: voice.id,
                        voiceName: voice.name,
                        status: .completed,
                        track: convertedTrack,
                        updatedAt: Date()
                    )
                )
                continue
            }

            if let job = preConversionManager.jobForVoice(voice, track: track),
               job.status == .queued || job.status == .converting {
                items.append(
                    ReadyVoiceItem(
                        id: "job-\(job.id.uuidString)",
                        voiceId: voice.id,
                        voiceName: voice.name,
                        status: job.status,
                        track: nil,
                        updatedAt: job.updatedAt
                    )
                )
            }
        }

        let localItems = localConvertedVoiceTracks.compactMap { record -> ReadyVoiceItem? in
            guard localRecord(record, matches: track),
                  FileManager.default.fileExists(atPath: record.filePath),
                  !items.contains(where: { item in
                      if let voiceId = record.voiceId, item.voiceId == voiceId {
                          return true
                      }
                      return item.voiceName.caseInsensitiveCompare(record.voiceName) == .orderedSame
                  }) else {
                return nil
            }

            let playableTrack = PlayableTrackDTO(
                id: record.id,
                title: "\(record.title) (Voice: \(record.voiceName))",
                artistName: record.artistName,
                playbackUrl: nil,
                playbackStoreID: track.playbackStoreID,
                isAIGenerated: true,
                duration: nil,
                fileUrl: record.filePath,
                artworkURL: record.artworkURL.flatMap(URL.init(string:))
            )

            return ReadyVoiceItem(
                id: "local-\(record.id.uuidString)",
                voiceId: record.voiceId,
                voiceName: record.voiceName,
                status: .completed,
                track: playableTrack,
                updatedAt: record.createdAt
            )
        }

        items.append(contentsOf: localItems)
        return items.sorted {
            if $0.isReady != $1.isReady { return $0.isReady && !$1.isReady }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func localRecord(_ record: ConvertedVoiceTrackRecord, matches track: PlayableTrackDTO) -> Bool {
        let titleMatches = normalized(record.title) == normalized(track.title)
        let recordArtist = normalized(record.artistName ?? "")
        let trackArtist = normalized(track.artistName ?? "")
        return titleMatches && (recordArtist.isEmpty || trackArtist.isEmpty || recordArtist == trackArtist)
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @ViewBuilder
    private func readyVoicesSection(
        items: [ReadyVoiceItem],
        viewStore: ViewStore<ViewState, PlayerReducer.Action>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready voices")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button(action: {
                            playReadyVoice(item, viewStore: viewStore)
                        }) {
                            HStack(spacing: 7) {
                                if item.isReady {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10, weight: .bold))
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.68)
                                }

                                Text(item.voiceName)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)

                                if !item.isReady {
                                    Text(item.status.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                            }
                            .foregroundColor(.white.opacity(item.isReady ? 0.92 : 0.62))
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(item.isReady ? 0.16 : 0.08))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!item.isReady)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 16)
    }

    private func playReadyVoice(
        _ item: ReadyVoiceItem,
        viewStore: ViewStore<ViewState, PlayerReducer.Action>
    ) {
        guard let track = item.track else { return }
        let seekPosition = audioManager.currentTime
        viewStore.send(.startPlayback([track]))
        if seekPosition > 0.5 {
            audioManager.pendingSeekPosition = seekPosition
        }
    }

    struct SeekBar: View {
        @Binding var value: Double
        let duration: Double
        var isEnabled: Bool = true
        var isScrubbing: Bool = false
        var onEditingChanged: (Bool) -> Void
        var onSeek: (Double) -> Void

        private func formatTime(_ time: Double) -> String {
            guard time.isFinite else { return "00:00" }
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        var body: some View {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let progress = max(0, min(1, duration > 0 ? value / duration : 0))
                let knobX = progress * width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.primaryAccent, AppTheme.secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(knobX, 0), height: 6)

                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 22 : 18, height: isScrubbing ? 22 : 18)
                        .offset(x: min(max(knobX - (isScrubbing ? 11 : 9), -9), width - 9))
                        .shadow(color: isScrubbing ? AppTheme.primaryAccent.opacity(0.6) : .black.opacity(0.15),
                                radius: isScrubbing ? 8 : 4, x: 0, y: 1)
                        .scaleEffect(isScrubbing ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isScrubbing)

                    if isScrubbing {
                        Text(formatTime(value))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryAccent.opacity(0.85))
                            )
                            .position(x: min(max(knobX, 24), width - 24), y: -14)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            onEditingChanged(true)
                            let x = min(max(gesture.location.x, 0), width)
                            value = (x / width) * duration
                        }
                        .onEnded { gesture in
                            guard isEnabled else { return }
                            let x = min(max(gesture.location.x, 0), width)
                            let target = (x / width) * duration
                            value = target
                            onEditingChanged(false)
                            onSeek(target)
                        }
                )
                .opacity(isEnabled ? 1 : 0.5)
            }
            .frame(height: 24)
        }
    }
    
    struct LocalDemoTrack: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let artist: String
        let fileName: String 
    }
    
    let demoTracks: [LocalDemoTrack] = [
        LocalDemoTrack(title: "Fix You", artist: "Coldplay", fileName: "fixyou.mp3"),
        LocalDemoTrack(title: "Feels Like Falling In Love", artist: "Coldplay", fileName: "feelslikefallinginlove.mp3")
    ]
    
    func remixDemoTrack(_ track: LocalDemoTrack, completion: @escaping (Result<URL, Error>) -> Void) {
        if let fileURL = Bundle.main.url(forResource: track.fileName, withExtension: nil) {
            uploadFileToAIConvert(fileURL: fileURL, completion: completion)
        } else {
            completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not find the bundled MP3 file."])))
        }
    }
    
    func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Call the Beam SVC server
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
    
    @MainActor
    private func loadAvailableVoices() async {
        do {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw VoiceConversionError.serverError("Invalid Beam SVC voices URL")
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VoiceConversionError.serverError("Beam SVC voices HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            struct VoiceListPayload: Decodable {
                let voices: [VoiceInfo]
            }
            let payload = try JSONDecoder().decode(VoiceListPayload.self, from: data)
            availableVoices = payload.voices.filter { $0.voiceType == "singer" }
            print("✅ Loaded \(availableVoices.count) Beam SVC singer voices")
        } catch {
            availableVoices = VoiceInfo.beamSVCFallbackVoices.filter { $0.voiceType == "singer" }
            showVoiceConversionError = true
            voiceConversionErrorMessage = "Failed to load the Beam SVC voice list: \(error.localizedDescription)"
        }
    }
    
    private func cancelVoiceConversion() {
        voiceConversionTask?.cancel()
        voiceConversionTask = nil
        isVoiceConverting = false
        fullTrackJobProgress = 0
        fullTrackJobStage = nil
        voiceConversionStatusSubtitle = "Conversion cancelled"
    }

    private func performVoiceConversion(with voice: VoiceInfo) {
        let reducerTrack = ViewStore(store, observe: { $0.currentTrack }).state
        let audioMeta = audioManager.currentTrackMetadata
        let resolvedTitle = reducerTrack?.title ?? audioMeta.title
        let resolvedArtist = reducerTrack?.artistName ?? audioMeta.artist

        guard let title = resolvedTitle else {
            showVoiceConversionError = true
            voiceConversionErrorMessage = "No track is currently playing."
            return
        }

        // Cache hit
        if let reducerTrack {
            if let convertedTrack = preConversionManager.latestConvertedTrack(for: reducerTrack, voiceId: voice.id) {
                let fileURL = convertedTrack.fileUrl.flatMap { URL(string: $0) } ?? convertedTrack.playbackUrl.flatMap { URL(string: $0) }
                if let fileURL {
                    startConvertedPlayback(
                        fileURL: fileURL,
                        title: title,
                        artistName: resolvedArtist,
                        voiceName: voice.name,
                        artworkURL: reducerTrack.artworkURL
                    )
                    TTFATelemetry.shared.recordPlaybackStarted(trackTitle: title, voiceId: voice.id)
                    return
                }
            }
        }

        // Stop playback
        voiceConversionTask?.cancel()
        isVoiceConverting = true
        voiceConversionStatusTitle = "Converting voice..."
        voiceConversionStatusSubtitle = "Converting the full song. This may take some time depending on song length"

        voiceConversionTask = Task {
            await audioManager.stop()
            do {
                let audioData: Data = try await resolveAudioData(reducerTrack: reducerTrack, title: title)
                let isSingerVoice = voice.id.contains("_singer") || voice.voiceType == "singer"
                let resolvedVoiceType = isSingerVoice ? "singer" : (voice.voiceType ?? "default")

                TTFATelemetry.shared.recordConversionRequestStart(trackTitle: title, voiceId: voice.id)
                voiceConversionStatusSubtitle = "Requesting full-song conversion from the server"

                guard let provider = voiceConversionService as? BeamSVCVoiceConversionProvider else {
                    throw VoiceConversionError.serverError("Beam SVC provider is unavailable.")
                }

                let job = try await provider.submitAsyncJob(
                    audioData: audioData,
                    voiceId: voice.id,
                    voiceType: resolvedVoiceType
                )

                await MainActor.run {
                    voiceConversionStatusSubtitle = "Converting the full song. Please wait"
                }

                let convertedData = try await provider.pollJobUntilFinished(jobId: job.jobId) { progress, stage in
                    Task { @MainActor in
                        fullTrackJobProgress = progress
                        fullTrackJobStage = stage
                        if let stage {
                            voiceConversionStatusSubtitle = stage
                        }
                    }
                }

                TTFATelemetry.shared.recordConversionRequestEnd(trackTitle: title, voiceId: voice.id)

                let fileURL = try await saveConvertedAudio(
                    audioData: convertedData,
                    title: title,
                    artistName: resolvedArtist,
                    voiceId: voice.id,
                    voiceName: voice.name,
                    artworkURL: reducerTrack?.artworkURL
                )

                await MainActor.run {
                    localConvertedVoiceTracks = ConvertedVoiceTrackStore.load()
                    startConvertedPlayback(
                        fileURL: fileURL,
                        title: title,
                        artistName: resolvedArtist,
                        voiceName: voice.name,
                        artworkURL: reducerTrack?.artworkURL
                    )
                    TTFATelemetry.shared.recordPlaybackStarted(trackTitle: title, voiceId: voice.id)
                    isVoiceConverting = false
                    voiceConversionTask = nil
                    fullTrackJobProgress = 0
                    fullTrackJobStage = nil
                }

            } catch {
                await MainActor.run {
                    isVoiceConverting = false
                    fullTrackJobProgress = 0
                    fullTrackJobStage = nil
                    voiceConversionTask = nil
                    if error is CancellationError {
                        voiceConversionErrorMessage = ""
                        return
                    }
                    showVoiceConversionError = true
                    if let nsError = error as NSError?,
                       nsError.domain == NSCocoaErrorDomain,
                       nsError.code == NSFileReadNoSuchFileError {
                        voiceConversionErrorMessage = "Voice conversion failed: Could not find an audio file to play. Play it again and retry."
                    } else {
                        voiceConversionErrorMessage = "Voice conversion failed: \(error.localizedDescription)"
                    }
                    print("❌ Voice conversion error: \(error)")
                }
            }
        }
    }
    
    private func performDirectBeamSVCVoiceConversion(
        audioData: Data,
        voiceId: String,
        voiceType: String?,
        trimStart: Double?,
        trimDuration: Double?,
        trackTitle: String
    ) async throws -> Data {
        let isSingerVoice = voiceId.contains("_singer") || voiceType == "singer"
        let resolvedVoiceType = isSingerVoice ? "singer" : (voiceType ?? "default")
        print("🧭 performVoiceConversion provider=beam_svc voiceId=\(voiceId) voiceType=\(resolvedVoiceType)")
        
        TTFATelemetry.shared.recordConversionRequestStart(trackTitle: trackTitle, voiceId: voiceId)
        let result = try await voiceConversionService.convert(
            audioData: audioData,
            voiceId: voiceId,
            voiceType: resolvedVoiceType,
            trimStart: trimStart,
            trimDuration: trimDuration
        )
        TTFATelemetry.shared.recordConversionRequestEnd(trackTitle: trackTitle, voiceId: voiceId)
        return result
    }

    private func saveConvertedAudio(
        audioData: Data,
        title: String,
        artistName: String?,
        voiceId: String,
        voiceName: String,
        artworkURL: URL?
    ) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let safeTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let safeVoice = voiceName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "voice_converted_\(safeTitle)_\(safeVoice)_\(Int(Date().timeIntervalSince1970)).mp3"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        try audioData.write(to: fileURL)
        _ = try? ConvertedVoiceTrackStore.save(
            title: title,
            artistName: artistName,
            voiceId: voiceId,
            voiceName: voiceName,
            filePath: fileURL.path,
            artworkURL: artworkURL
        )
        return fileURL
    }

    @MainActor
    private func startConvertedPlayback(
        fileURL: URL,
        title: String,
        artistName: String?,
        voiceName: String,
        artworkURL: URL?,
        seekPosition: Double? = nil
    ) {
        let asset = AVAsset(url: fileURL)
        Task {
            let duration = try? await asset.load(.duration)
            let durationSeconds: Double? = duration.map(CMTimeGetSeconds)
            let track = PlayableTrackDTO(
                id: UUID(),
                title: "\(title) (Voice: \(voiceName))",
                artistName: artistName ?? "Unknown Artist",
                playbackUrl: nil,
                playbackStoreID: nil,
                isAIGenerated: true,
                duration: (durationSeconds?.isFinite == true) ? durationSeconds : nil,
                fileUrl: fileURL.path,
                artworkURL: artworkURL
            )
            store.send(.startPlayback([track]))
            // When replacing with the full track, seek to the preview playback position (applied automatically after playAIMusic is ready)
            if let seekTo = seekPosition, seekTo > 0.5 {
                audioManager.pendingSeekPosition = seekTo
                print("🎯 [Playback] Full track swap → pending seek to \(String(format: "%.1f", seekTo))s")
            }
        }
    }

    /// Resolve audio Data for voice conversion.
    /// Order: currently-playing AVPlayer URL → AI track fileUrl → Jamendo audio URL → bundled demo.
    private func resolveAudioData(reducerTrack: PlayableTrackDTO?, title: String?) async throws -> Data {
        // 1. Currently playing via AudioManager
        if let currentURL = audioManager.currentAudioURL {
            print("🎵 VoiceConversion: using currentAudioURL=\(currentURL)")
            if currentURL.isFileURL {
                return try Data(contentsOf: currentURL)
            }
            if let cached = await AudioDataCache.shared.data(for: currentURL) {
                return cached
            }
            let (data, _) = try await URLSession.shared.data(from: currentURL)
            await AudioDataCache.shared.store(data, for: currentURL)
            return data
        }

        // 2. AI track local fileUrl
        if let track = reducerTrack, track.isAIGenerated, let fileUrlString = track.fileUrl {
            let url: URL? = {
                if fileUrlString.hasPrefix("file://") { return URL(string: fileUrlString) }
                if fileUrlString.hasPrefix("/") { return URL(fileURLWithPath: fileUrlString) }
                return URL(string: fileUrlString)
            }()
            if let url = url {
                print("🎵 VoiceConversion: using AI track fileUrl=\(url)")
                if url.isFileURL {
                    return try Data(contentsOf: url)
                }
                if let cached = await AudioDataCache.shared.data(for: url) {
                    return cached
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                await AudioDataCache.shared.store(data, for: url)
                return data
            }
        }

        // 3. Jamendo audio download
        if let audioURL = try await fetchAudioURL(reducerTrack: reducerTrack, fallbackTitle: title) {
            print("🎵 VoiceConversion: downloading Jamendo audio=\(audioURL)")
            if audioURL.isFileURL {
                return try Data(contentsOf: audioURL)
            }
            if let cached = await AudioDataCache.shared.data(for: audioURL) {
                return cached
            }
            let data = try await JamendoService.shared.downloadAudioData(from: audioURL.absoluteString)
            await AudioDataCache.shared.store(data, for: audioURL)
            return data
        }

        // 4. Last resort: bundled demo sample
        if let demoURL = Bundle.main.url(forResource: "fixyou", withExtension: "mp3") {
            print("⚠️ VoiceConversion: falling back to bundled demo sample")
            return try Data(contentsOf: demoURL)
        }

        throw VoiceConversionError.invalidAudioData
    }

    private func fetchAudioURL(reducerTrack: PlayableTrackDTO?, fallbackTitle: String?) async throws -> URL? {
        if let urlString = reducerTrack?.fileUrl ?? reducerTrack?.playbackUrl,
           let url = URL(string: urlString) {
            return url
        }

        let searchTerm: String
        if let title = reducerTrack?.title, !title.isEmpty {
            searchTerm = title
        } else if let fallback = fallbackTitle, !fallback.isEmpty {
            searchTerm = fallback
        } else {
            return nil
        }

        let tracks = try await JamendoService.shared.searchTracks(query: searchTerm, limit: 1)
        guard let track = tracks.first, let url = URL(string: track.audiodownload) else {
            return nil
        }
        return url
    }
}

struct VoiceSelectionSheet: View {
    let voices: [VoiceInfo]
    let onVoiceSelected: (VoiceInfo) -> Void
    let onCancel: () -> Void
    var currentTrack: PlayableTrackDTO?
    var preConversionManager: PreConversionManager?
    
    @State private var searchText = ""
    
    var filteredVoices: [VoiceInfo] {
        if searchText.isEmpty {
            return voices
        } else {
            return voices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.englishDescription?.localizedCaseInsensitiveContains(searchText) == true ||
                voice.englishCategory.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var groupedVoices: [String: [VoiceInfo]] {
        Dictionary(grouping: filteredVoices) { voice in
            voice.englishCategory
        }
    }
    
    private func statusBadge(for voice: VoiceInfo) -> (text: String, color: Color)? {
        guard let track = currentTrack, let manager = preConversionManager else { return nil }
        guard let status = manager.conversionStatusForVoice(voice, track: track) else { return nil }
        switch status {
        case .completed:
            return ("✓ Done", .green)
        case .converting, .queued:
            return ("Converting", .orange)
        case .failed:
            return ("✗ Failed", .red)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("Select Voice")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField("Search voices", text: $searchText)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    if groupedVoices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.badge.exclamationmark")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.7))
                            Text("No voices available")
                                .foregroundColor(.white)
                            Text("Could not load the Kits AI model list or the search returned no results")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(groupedVoices.keys.sorted()), id: \.self) { category in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(category)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 24)

                                    ForEach(groupedVoices[category] ?? [], id: \.id) { voice in
                                        VoiceRowView(voice: voice, badge: statusBadge(for: voice)) {
                                            onVoiceSelected(voice)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                Spacer(minLength: 0)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.85), Color.purple.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(24)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onTapGesture {
            onCancel()
        }
    }
}

struct VoiceAvatarView: View {
    let voice: VoiceInfo

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.28))

            if let url = voice.artistImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(voice.avatarInitials)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
            } else {
                Text(voice.avatarInitials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 42, height: 42)
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

struct VoiceRowView: View {
    let voice: VoiceInfo
    var badge: (text: String, color: Color)?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VoiceAvatarView(voice: voice)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(voice.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let voiceType = voice.voiceType {
                            Text(voiceType == "singer" ? "🎤" : "🎵")
                                .font(.system(size: 14))
                        }
                        
                        if let badge = badge {
                            Text(badge.text)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(badge.color.opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let description = voice.englishDescription {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(voice.englishCategory)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if let language = voice.language, !language.isEmpty {
                            Text("• \(language.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
