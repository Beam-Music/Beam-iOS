//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Voice Conversion Models
struct VoiceInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let isCustom: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "voice_id"
        case name
        case category
        case description
        case isCustom = "is_custom"
    }
}

struct VoiceListResponse: Codable {
    let voices: [VoiceInfo]
}

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
                    .foregroundColor(Color.white.opacity(0.5))
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

// MARK: - AI Music Toggle
struct AIMusicToggleView: View {
    let isAIPlaying: Bool
    let onToggle: (Bool) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Music Mode")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isAIPlaying },
                    set: { onToggle($0) }
                ))
                .tint(Color.purple)
            }
            
            if isAIPlaying {
                Text("Play AI-generated music")
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
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

// MARK: - Custom Remix/AI Toggle (Figma style)
struct RemixAIToggle: View {
    @Binding var isAIVersion: Bool
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let circleSize = height * 0.8
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: isAIVersion ? [Color.purple, Color.black] : [Color.white, Color.gray.opacity(0.2)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .clipShape(Capsule())
                Path { path in
                    let w = width
                    let h = height
                    path.addArc(center: CGPoint(x: w*0.2, y: h*0.7), radius: h*0.7, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                    path.addArc(center: CGPoint(x: w*0.8, y: h*0.3), radius: h*0.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(isAIVersion ? Color.white.opacity(0.18) : Color.purple.opacity(0.18), lineWidth: 2)
                Circle()
                    .fill(
                        RadialGradient(gradient: Gradient(colors: isAIVersion ? [Color.white.opacity(0.7), Color.purple.opacity(0.7)] : [Color.gray.opacity(0.2), Color.white]), center: .center, startRadius: 2, endRadius: circleSize)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                    .offset(x: isAIVersion ? width/2 - circleSize/1.5 : -width/2 + circleSize/1.5)
                    .animation(.easeInOut(duration: 0.22), value: isAIVersion)
                ZStack {
                    if !isAIVersion {
                        Text("Original")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    } else {
                        Text("AI Version")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isAIVersion.toggle() } }
        }
        .frame(height: 48)
        .frame(minWidth: 140, maxWidth: 180)
    }
}

struct Artist: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let imageName: String // asset name or URL
}

struct RemixArtistPickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedArtists: [Artist]
    @State private var searchText: String = ""
    let allArtists: [Artist]
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 80, height: 8)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField("Search artists", text: $searchText)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.purple)
                    .font(.system(size: 16, weight: .bold))
                }
                .padding(.horizontal)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(allArtists.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }) { artist in
                            Button(action: {
                                if selectedArtists.contains(artist) {
                                    selectedArtists.removeAll { $0 == artist }
                                } else {
                                    selectedArtists.append(artist)
                                }
                            }) {
                                HStack(spacing: 16) {
                                    Image(artist.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    Text(artist.name)
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .medium))
                                    Spacer()
                                    if selectedArtists.contains(artist) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 18)
                                .background(selectedArtists.contains(artist) ? Color.purple.opacity(0.6) : Color.clear)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
                Spacer(minLength: 0)
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.85), Color.purple.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                    .cornerRadius(24)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onTapGesture {
            isPresented = false
        }
    }
}

// === Demo Tracks Section ===
struct LocalDemoTrack: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let fileName: String // 번들 내 파일명
}

let demoTracks: [LocalDemoTrack] = [
    LocalDemoTrack(title: "Fix You", artist: "Coldplay", fileName: "fixyou.mp3"),
    LocalDemoTrack(title: "Feels Like Falling In Love", artist: "Coldplay", fileName: "feelslikefallinginlove.mp3")
]

func urlForDemoTrack(_ track: LocalDemoTrack) -> URL? {
    Bundle.main.url(forResource: track.fileName, withExtension: nil)
}

// MARK: - Main Player View
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
    // === IMSLP/AI Remix 관련 상태 ===
    @State private var showIMSLPList = false // 더 이상 사용하지 않음
    @State private var isRemixing = false
    @State private var remixedAudioURL: URL? = nil
    @State private var isAIVersion: Bool = false
    @State private var showNoMatchAlert = false
    
    // Voice conversion states
    @State private var isVoiceConverting = false
    @State private var showVoiceSelectionSheet = false
    @State private var availableVoices: [VoiceInfo] = []
    @State private var selectedVoice: VoiceInfo?
    @State private var showVoiceConversionError = false
    @State private var voiceConversionErrorMessage = ""
    
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
                // Figma background: solid #63477C + linear gradient (20% opacity)
                Color(hex: "#63477C")
                    .ignoresSafeArea()
                LinearGradient(
                    gradient: Gradient(colors: [Color.red.opacity(0.2), Color.purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    // HStack {
                    //     Button(action: { isMiniPlayerVisible = false }) {
                    //         HStack(spacing: 6) {
                    //             Image(systemName: "chevron.left")
                    //                 .font(.system(size: 18, weight: .bold))
                    //                 .foregroundColor(.white)
                    //             Text("Playlists")
                    //                 .font(.system(size: 18, weight: .semibold))
                    //                 .foregroundColor(.white)
                    //         }
                    //     }
                    //     Spacer()
                    // }
                    // .padding(.top, 24)
                    // .padding(.horizontal)
                    // Spacer().frame(height: 8)
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
                        } else {
                            AlbumArtView(albumArt: audioManager.currentTrackMetadata.albumArt)
                                .frame(width: 320, height: 320)
                                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                                .cornerRadius(24)
                                .shadow(radius: 14)
                                .padding(.bottom, 8)
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
                            Slider(value: $audioManager.currentTime, in: 0...audioManager.duration, onEditingChanged: { editing in
                                if !editing {
                                    Task {
                                        await audioManager.seek(to: audioManager.currentTime)
                                    }
                                }
                            })
                            .accentColor(.white)
                        } else {
                            Slider(value: .constant(0), in: 0...1)
                                .disabled(true)
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
                        Button(action: {/* TODO: Show Lyrics */}) {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                Text("View Lyrics")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .clipShape(Capsule())
                        }
                        Button(action: {/* TODO: Show Artist Info */}) {
                            HStack(spacing: 6) {
                                Image(systemName: "person")
                                let artist = audioManager.currentTrackMetadata.artist ?? ""
                                Text("")
                                Text("\(artist)Learn more about ")
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
                    // === AI 버전/Remix/Voice Conversion 토글 ===
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
                                                Task {
                                                    do {
                                                        try await AudioManager.shared.playAIMusic(from: url.absoluteString, title: demoTrack.title, artist: demoTrack.artist)
                                                    } catch {
                                                        print("Failed to play AI converted song: \(error)")
                                                    }
                                                }
                                            case .failure(let error):
                                                print("AI conversion failed: \(error)")
                                            }
                                        }
                                    }
                                } else {
                                    // Show notice for non-bundled songs
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
                            
                            // Voice Conversion Button
                            Button(action: {
                                Task {
                                    await loadAvailableVoices()
                                    showVoiceSelectionSheet = true
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
                                        .background(Color.blue.opacity(0.7).cornerRadius(24))
                                )
                            }
                        }
                        
                        RemixAIToggle(isAIVersion: Binding(
                            get: { viewStore.isAIMusicEnabled },
                            set: { newValue in viewStore.send(.toggleAIMusic(newValue)) }
                        ))
                        .frame(width: 180)
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
                // === AI 변환 중 ProgressView ===
                if isRemixing {
                    ProgressView("AI converting/remixing...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
                
                // === Voice Conversion 중 ProgressView ===
                if isVoiceConverting {
                    ProgressView("Converting voice...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
            }
            // === 매칭 실패 Alert ===
            .alert("Could not find a public-domain song.", isPresented: $showNoMatchAlert) {
                Button("OK", role: .cancel) { showNoMatchAlert = false }
            }
            
            // === Voice Conversion Error Alert ===
            .alert("Voice Conversion Failed", isPresented: $showVoiceConversionError) {
                Button("OK", role: .cancel) { showVoiceConversionError = false }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .onAppear {
                viewStore.send(.syncPlaybackState)
                if !viewStore.isPlaying {
                    viewStore.send(.playPause)
                }
                libraryStore.send(.fetchUserPlaylists)
            }
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
            }
            .sheet(isPresented: $isPlaylistSelectSheetPresented, onDismiss: {
                libraryStore.send(.fetchUserPlaylists)
            }) {
                let playlists = ViewStore(libraryStore, observe: { $0.playlists }).state
                if let track = viewStore.currentTrack {
//                    PlaylistSelectSheet(
//                        playlists: playlists,
//                        onSelect: { playlist in
//                            addSongToPlaylist(track: track, playlist: playlist)
//                            isPlaylistSelectSheetPresented = false
//                        },
//                        onCancel: {
//                            isPlaylistSelectSheetPresented = false
//                        }
//                    )
                }
            }
            .alert("Added to playlist!", isPresented: $showAddSuccess) {
                Button("OK", role: .cancel) { showAddSuccess = false }
            }
            
            // Voice Selection Sheet
            .sheet(isPresented: $showVoiceSelectionSheet) {
                VoiceSelectionSheet(
                    availableVoices: availableVoices,
                    selectedVoice: $selectedVoice,
                    onVoiceSelected: { voice in
                        selectedVoice = voice
                        showVoiceSelectionSheet = false
                        performVoiceConversion(with: voice)
                    },
                    onCancel: {
                        showVoiceSelectionSheet = false
                    }
                )
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Voice Conversion Functions
    
    @MainActor
    private func loadAvailableVoices() async {
        do {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let voiceList = try JSONDecoder().decode(VoiceListResponse.self, from: data)
            availableVoices = voiceList.voices
        } catch {
            print("Failed to load voices: \(error)")
            voiceConversionErrorMessage = "Failed to load the voice list: \(error.localizedDescription)"
            showVoiceConversionError = true
        }
    }
    
    private func performVoiceConversion(with voice: VoiceInfo) {
        guard let currentTitle = audioManager.currentTrackMetadata.title?.lowercased(),
              let currentArtist = audioManager.currentTrackMetadata.artist?.lowercased(),
              let demoTrack = demoTracks.first(where: {
                  $0.title.lowercased() == currentTitle && $0.artist.lowercased() == currentArtist
              }),
              let fileURL = Bundle.main.url(forResource: demoTrack.fileName, withExtension: nil) else {
            voiceConversionErrorMessage = "Could not find the currently playing song."
            showVoiceConversionError = true
            return
        }
        
        isVoiceConverting = true
        
        Task {
            do {
                let audioData = try Data(contentsOf: fileURL)
                
                // Voice conversion API call
                guard let url = URL(string: Endpoints.VoiceConversion.convert) else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var body = Data()
                
                // Add audio file
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"audioFile\"; filename=\"audio.mp3\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
                body.append(audioData)
                body.append("\r\n".data(using: .utf8)!)
                
                // Add voice ID
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"voiceId\"\r\n\r\n".data(using: .utf8)!)
                body.append(voice.id.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
                
                // Add output format
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"outputFormat\"\r\n\r\n".data(using: .utf8)!)
                body.append("mp3".data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
                
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                request.httpBody = body
                
                let (convertedAudioData, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                // Save converted audio to temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice_converted_\(voice.name).mp3")
                try convertedAudioData.write(to: tempURL)
                
                await MainActor.run {
                    isVoiceConverting = false
                    // Play the converted audio
                    Task {
                        do {
                            try await AudioManager.shared.playAIMusic(
                                from: tempURL.absoluteString,
                                title: "\(demoTrack.title) (Voice: \(voice.name))",
                                artist: demoTrack.artist
                            )
                        } catch {
                            print("Voice converted audio playback failed: \(error)")
                            voiceConversionErrorMessage = "Failed to play converted voice audio: \(error.localizedDescription)"
                            showVoiceConversionError = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isVoiceConverting = false
                    voiceConversionErrorMessage = "Voice conversion failed: \(error.localizedDescription)"
                    showVoiceConversionError = true
                }
            }
        }
    }
    
    private func addSongToPlaylist(track: PlayableTrackDTO, playlist: PlaylistSummaryDTO) {
        guard let playlistID = playlist.id?.uuidString else { return }
        let urlString = Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID)
        
        Task {
            guard let token = await TokenStorage.shared.fetchToken() else { return }
            
            let body: [String: String] = [
                "songId": track.playbackStoreID ?? track.id.uuidString,
                "title": track.title,
                "artistName": track.artistName ?? ""
            ]
            
            do {
                var request = URLRequest(url: URL(string: urlString)!)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    showAddSuccess = true
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("Failed to add playlist item: Status \(httpResponse.statusCode)")
                }
            } catch {
                print("Failed to add playlist item: \(error)")
            }
        }
    }
}

// MARK: - Helper Functions (Outside PlayerView)

func remixDemoTrack(_ track: LocalDemoTrack, completion: @escaping (Result<URL, Error>) -> Void) {
    if let fileURL = Bundle.main.url(forResource: track.fileName, withExtension: nil) {
        uploadFileToAIConvert(fileURL: fileURL, completion: completion)
    } else {
        completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not find the bundled MP3 file."])))
    }
}

func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
    let url = URL(string: Endpoints.aiConvert)! // Endpoints에서 관리
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var data = Data()
    let filename = fileURL.lastPathComponent
    let mimetype = "audio/mpeg" // mp3 등 실제 파일 타입에 맞게

    guard let fileData = try? Data(contentsOf: fileURL) else {
        completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not read the file."])))
        return
    }

    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
    data.append(fileData)
    data.append("\r\n".data(using: .utf8)!)
    data.append("--\(boundary)--\r\n".data(using: .utf8)!)

    let task = URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let responseData = responseData else {
            completion(.failure(NSError(domain: "NoData", code: 0, userInfo: nil)))
            return
        }
        // 임시 파일로 Save
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ai_version.mp3")
        do {
            try responseData.write(to: tempURL)
            completion(.success(tempURL))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}
