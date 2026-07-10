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

// MARK: - Custom Remix/AI Toggle (Figma 스타일)
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
    @State private var voiceConversionStatusTitle = "음성 변환 중..."
    @State private var voiceConversionStatusSubtitle = "미리듣기 구간을 준비하고 있어요"
    @State private var isFullTrackConversionInProgress = false
    @State private var fullTrackJobProgress: Int = 0
    @State private var fullTrackJobStage: String?
    @State private var showLyricsSheet = false
    @State private var lyricsText = ""
    @State private var lyricsTitle = "가사보기"
    @State private var showArtistInfoSheet = false
    @State private var artistInfoTitle = "아티스트 정보"
    @State private var artistInfoText = ""
    @State private var artistInfoImageURL: URL? = nil
    @State private var isScrubbing = false
    @State private var trackID: UUID? = nil
    
    enum VoiceSelectionMode {
        case preview
        case preconvert
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
                                Text("로딩 중...")
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            Task {
                                await presentLyrics(for: viewStore.currentTrack)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                Text("가사/설명 보기")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .clipShape(Capsule())
                        }
                        Button(action: {
                            Task {
                                await presentArtistInfo(for: viewStore.currentTrack)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person")
                                let artist = audioManager.currentTrackMetadata.artist ?? ""
                                Text("\(artist)에 대해 더 알아보기")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 18) {
                            Button(action: {
                                if let currentTitle = audioManager.currentTrackMetadata.title?.lowercased(),
                                   let currentArtist = audioManager.currentTrackMetadata.artist?.lowercased(),
                                   let demoTrack = demoTracks.first(where: {
                                       $0.title.lowercased() == currentTitle && $0.artist.lowercased() == currentArtist
                                   }) {
                                    isRemixing = true
                                    remixDemoTrack(demoTrack) { result in
                                        DispatchQueue.main.async {
                                            isRemixing = false
                                            switch result {
                                            case .success(let url):
                                                // 변환된 AI 트랙을 PlayerReducer로 흘려 MiniPlayer/컨트롤 상태 일관화
                                                let currentArtworkURL = viewStore.currentTrack?.artworkURL
                                                let track = PlayableTrackDTO(
                                                    id: UUID(),
                                                    title: demoTrack.title,
                                                    artistName: demoTrack.artist,
                                                    playbackUrl: nil,
                                                    playbackStoreID: nil,
                                                    isAIGenerated: true,
                                                    duration: nil,
                                                    fileUrl: url.absoluteString,
                                                    artworkURL: currentArtworkURL
                                                )
                                                viewStore.send(.startPlayback([track]))
                                            case .failure(let error):
                                                print("AI 변환 실패: \(error)")
                                            }
                                        }
                                    }
                                } else {
                                    // 내장곡이 아니면 안내
                                    showNoMatchAlert = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "music.note")
                                    Text("Remix")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(viewStore.isAIMusicEnabled ? 0.7 : 0.25), lineWidth: 2)
                                        .background(
                                            viewStore.isAIMusicEnabled ? Color.purple.opacity(0.7).cornerRadius(24) : Color.clear.cornerRadius(24)
                                        )
                                )
                            }
                            .disabled(!viewStore.isAIMusicEnabled)
                            .opacity(viewStore.isAIMusicEnabled ? 1 : 0.4)
                            
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

                            Button(action: {
                                voiceSelectionMode = .preconvert
                                Task {
                                    await preConversionManager.loadAvailableVoices()
                                    await MainActor.run {
                                        showVoiceSelectionSheet = true
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tray.and.arrow.down")
                                    Text("선변환")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                        .background(AppTheme.preconvertButtonFill.cornerRadius(24))
                                )
                            }
                        }
                        if let currentTrack = viewStore.currentTrack,
                           let badge = preConversionManager.statusBadgeText(for: currentTrack, includeWarmupHint: true) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor(for: currentTrack))
                                    .frame(width: 8, height: 8)
                                
                                Text(badge)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                if let record = preConversionManager.latestJob(for: currentTrack),
                                   record.status == .failed {
                                    Button(action: {
                                        if let voice = preConversionManager.preferredVoice() {
                                            Task {
                                                await preConversionManager.enqueue(track: currentTrack, voice: voice)
                                            }
                                        }
                                    }) {
                                        Text("재시도")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.red.opacity(0.7))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
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
                    ProgressView("AI 변환/리믹스 중...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
                
                if isVoiceConverting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(voiceConversionStatusTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text(voiceConversionStatusSubtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        if isFullTrackConversionInProgress {
                            Text("미리듣기는 먼저 재생되고, 전체 곡은 완료되면 자동으로 바뀌어요")
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
            }
            .onChange(of: viewStore.currentTrack?.id) { _, newTrackID in
                guard newTrackID != nil, let currentTrack = viewStore.currentTrack else { return }
                Task {
                    await preConversionManager.warmup(track: currentTrack)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
                // Preview 종료 시 full track이 아직 준비 중이면 원곡으로 fallback
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
            .alert("플레이리스트에 추가되었습니다!", isPresented: $showAddSuccess) {
                Button("확인", role: .cancel) { showAddSuccess = false }
            }
            
            .alert("퍼블릭 도메인 곡을 찾을 수 없습니다.", isPresented: $showNoMatchAlert) {
                Button("확인", role: .cancel) { showNoMatchAlert = false }
            }
            
            .alert("음성 변환 실패", isPresented: $showVoiceConversionError) {
                Button("확인", role: .cancel) { showVoiceConversionError = false }
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
                                voiceConversionErrorMessage = "현재 재생 중인 곡이 없습니다."
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
            .alert("음성 변환 오류", isPresented: $showVoiceConversionError) {
                Button("확인") { }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .sheet(isPresented: $showLyricsSheet) {
                NavigationView {
                    ScrollView {
                        Text(lyricsText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle(lyricsTitle)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showArtistInfoSheet) {
                NavigationView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let artistInfoImageURL {
                                AsyncImage(url: artistInfoImageURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay { ProgressView() }
                                }
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            Text(artistInfoText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                    .navigationTitle(artistInfoTitle)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .overlay(
                ZStack(alignment: .top) {
                    // 전체 화면 오버레이: preview 변환 대기 중
                    if isVoiceConverting {
                        VStack(spacing: 20) {
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

                    // 상단 배너: 백그라운드에서 전체 곡 변환 중일 때 (preview는 재생 중)
                    if !isVoiceConverting && isFullTrackConversionInProgress {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text("전체 곡 변환 중...")
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
                                    Text("백그라운드에서 고품질 버전을 준비하고 있어요")
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
            completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "내장 mp3 파일을 찾을 수 없습니다."])))
        }
    }
    
    func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // 자체 Beam SVC 서버 호출
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
            availableVoices = payload.voices
            print("✅ Loaded \(availableVoices.count) Beam SVC voices")
        } catch {
            availableVoices = [
                VoiceInfo(id: "dionn_v1_singing", name: "Dionn V1 Singing", category: "Custom Licensed", description: "Beam SVC fallback voice", previewUrl: nil, language: ["en"], voiceType: "singer")
            ]
            showVoiceConversionError = true
            voiceConversionErrorMessage = "Beam SVC 음성 목록을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }
    
    private func performVoiceConversion(with voice: VoiceInfo) {
        let reducerTrack = ViewStore(store, observe: { $0.currentTrack }).state
        let audioMeta = audioManager.currentTrackMetadata
        let resolvedTitle = reducerTrack?.title ?? audioMeta.title
        let resolvedArtist = reducerTrack?.artistName ?? audioMeta.artist

        guard let title = resolvedTitle else {
            showVoiceConversionError = true
            voiceConversionErrorMessage = "현재 재생 중인 트랙이 없습니다."
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

        // 재생 중지
        isVoiceConverting = true
        voiceConversionStatusTitle = "음성 변환 중..."
        voiceConversionStatusSubtitle = "전체 곡을 변환하고 있어요. 곡 길이에 따라 시간이 걸릴 수 있습니다"

        Task {
            await audioManager.stop()
            do {
                let audioData: Data = try await resolveAudioData(reducerTrack: reducerTrack, title: title)
                let isSingerVoice = voice.id.contains("_singer") || voice.voiceType == "singer"
                let resolvedVoiceType = isSingerVoice ? "singer" : (voice.voiceType ?? "default")

                TTFATelemetry.shared.recordConversionRequestStart(trackTitle: title, voiceId: voice.id)
                voiceConversionStatusSubtitle = "서버에 전체 곡 변환을 요청하고 있어요"

                guard let provider = voiceConversionService as? BeamSVCVoiceConversionProvider else {
                    throw VoiceConversionError.serverError("Beam SVC provider를 사용할 수 없습니다.")
                }

                let job = try await provider.submitAsyncJob(
                    audioData: audioData,
                    voiceId: voice.id,
                    voiceType: resolvedVoiceType
                )

                await MainActor.run {
                    voiceConversionStatusSubtitle = "전체 곡을 변환 중이에요. 잠시만 기다려 주세요"
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
                    voiceName: voice.name,
                    artworkURL: reducerTrack?.artworkURL
                )

                await MainActor.run {
                    startConvertedPlayback(
                        fileURL: fileURL,
                        title: title,
                        artistName: resolvedArtist,
                        voiceName: voice.name,
                        artworkURL: reducerTrack?.artworkURL
                    )
                    TTFATelemetry.shared.recordPlaybackStarted(trackTitle: title, voiceId: voice.id)
                    isVoiceConverting = false
                    fullTrackJobProgress = 0
                    fullTrackJobStage = nil
                }

            } catch {
                await MainActor.run {
                    isVoiceConverting = false
                    fullTrackJobProgress = 0
                    fullTrackJobStage = nil
                    showVoiceConversionError = true
                    if let nsError = error as NSError?,
                       nsError.domain == NSCocoaErrorDomain,
                       nsError.code == NSFileReadNoSuchFileError {
                        voiceConversionErrorMessage = "음성 변환에 실패했습니다: 재생할 오디오 파일을 찾지 못했습니다. 다시 재생 후 시도해 주세요."
                    } else {
                        voiceConversionErrorMessage = "음성 변환에 실패했습니다: \(error.localizedDescription)"
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
            // full track 교체 시 preview 재생 위치로 seek (playAIMusic 준비 완료 후 자동 적용)
            if let seekTo = seekPosition, seekTo > 0.5 {
                audioManager.pendingSeekPosition = seekTo
                print("🎯 [Playback] Full track swap → pending seek to \(String(format: "%.1f", seekTo))s")
            }
        }
    }

    @MainActor
    private func presentLyrics(for track: PlayableTrackDTO?) async {
        guard let track else {
            lyricsTitle = "가사보기"
            lyricsText = "현재 재생 중인 곡이 없습니다."
            showLyricsSheet = true
            return
        }

        lyricsTitle = track.title

        do {
            var descriptionText: String? = nil

            if let trackID = track.playbackStoreID {
                let detail = try await AudiusService.shared.getTrack(id: trackID)
                descriptionText = detail.description
            }

            if (descriptionText == nil || descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) {
                let query = [track.title, track.artistName].compactMap { $0 }.joined(separator: " ")
                let results = try await AudiusService.shared.searchTracks(query: query, limit: 10)
                let matched = results.first {
                    $0.title.localizedCaseInsensitiveContains(track.title) &&
                    (track.artistName == nil || $0.user.name.localizedCaseInsensitiveContains(track.artistName ?? ""))
                } ?? results.first
                descriptionText = matched?.description
            }

            if let text = descriptionText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lyricsText = text
            } else {
                lyricsText = "이 트랙은 Audius에서 가사/설명 데이터가 제공되지 않습니다.\n\n현재 Beam에서는 Audius 트랙의 설명(description)을 가사 대체 정보로 보여주고 있어요."
            }
        } catch {
            lyricsText = "가사/설명 정보를 불러오지 못했습니다.\n\n\(error.localizedDescription)"
        }

        showLyricsSheet = true
    }

    @MainActor
    private func presentArtistInfo(for track: PlayableTrackDTO?) async {
        let artistName = track?.artistName ?? audioManager.currentTrackMetadata.artist
        let trimmedArtistName = artistName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedArtistName.isEmpty else {
            artistInfoTitle = "아티스트 정보"
            artistInfoText = "현재 재생 중인 아티스트 정보가 없습니다."
            artistInfoImageURL = nil
            showArtistInfoSheet = true
            return
        }

        artistInfoTitle = trimmedArtistName
        artistInfoText = "아티스트 정보를 불러오는 중..."
        artistInfoImageURL = nil
        showArtistInfoSheet = true

        do {
            let users = try await AudiusService.shared.searchUsers(query: trimmedArtistName, limit: 5)
            if let user = users.first(where: {
                $0.name.localizedCaseInsensitiveContains(trimmedArtistName) || trimmedArtistName.localizedCaseInsensitiveContains($0.name)
            }) ?? users.first {
                artistInfoImageURL = user.profilePicture?.url1000 ?? user.profilePicture?.url480 ?? user.profilePicture?.url150

                let tracks = try await AudiusService.shared.searchTracks(query: trimmedArtistName, limit: 10)
                let matchedTracks = tracks.filter {
                    $0.user.name.localizedCaseInsensitiveContains(user.name) || user.name.localizedCaseInsensitiveContains($0.user.name)
                }

                let topTracks = Array(matchedTracks.prefix(5)).map(\.title)
                let genres = Array(Set(matchedTracks.compactMap {
                    $0.genre?.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty })).sorted()

                var sections: [String] = ["플랫폼\nAudius"]
                if let handle = user.handle, !handle.isEmpty {
                    sections.append("핸들\n@\(handle)")
                }
                if !genres.isEmpty {
                    sections.append("장르\n\(genres.joined(separator: ", "))")
                }
                if !topTracks.isEmpty {
                    sections.append("대표 트랙\n" + topTracks.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
                }

                artistInfoText = sections.joined(separator: "\n\n")
                return
            }

            artistInfoText = "\(trimmedArtistName)에 대한 Audius 아티스트 정보를 찾지 못했습니다."
        } catch {
            artistInfoText = "아티스트 정보를 불러오지 못했습니다.\n\n\(error.localizedDescription)"
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
                voice.description?.localizedCaseInsensitiveContains(searchText) == true ||
                voice.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var groupedVoices: [String: [VoiceInfo]] {
        Dictionary(grouping: filteredVoices) { voice in
            voice.category
        }
    }
    
    private func statusBadge(for voice: VoiceInfo) -> (text: String, color: Color)? {
        guard let track = currentTrack, let manager = preConversionManager else { return nil }
        guard let status = manager.conversionStatusForVoice(voice, track: track) else { return nil }
        switch status {
        case .completed:
            return ("✓ 완료", .green)
        case .converting, .queued:
            return ("변환중", .orange)
        case .failed:
            return ("✗ 실패", .red)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("음성 선택")
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
                    TextField("음성 검색", text: $searchText)
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
                            Text("사용 가능한 음성이 없습니다")
                                .foregroundColor(.white)
                            Text("Kits AI 모델 목록을 불러오지 못했거나 검색 결과가 비어 있습니다")
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

struct VoiceRowView: View {
    let voice: VoiceInfo
    var badge: (text: String, color: Color)?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
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
                    
                    if let description = voice.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(voice.category)
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
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
