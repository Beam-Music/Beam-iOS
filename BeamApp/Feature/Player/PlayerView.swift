//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation

// MARK: - Voice Conversion Errors
enum VoiceConversionError: LocalizedError {
    case serverError(String)
    case invalidAudioData
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .invalidAudioData:
            return "Invalid audio data received"
        case .timeout:
            return "Voice conversion timed out"
        }
    }
}

// MARK: - Voice Conversion Models
struct VoiceInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let previewUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id // Supertone API는 id 그대로 반환
        case name
        case category
        case description
        case previewUrl = "preview_url"
    }
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
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Sliding circle
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
                
                // Labels
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

// MARK: - Artist Model
struct Artist {
    let id: UUID = UUID()
    let name: String
    let imageName: String // asset name or URL
}

// MARK: - Main Player View
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
                                Text("가사보기")
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
                                                        print("AI 변환 곡 재생 실패: \(error)")
                                                    }
                                                }
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
                            
                            // Voice Conversion Button
                            Button(action: {
                                Task {
                                    await loadAvailableVoices()
                                }
                                showVoiceSelectionSheet = true
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
                    ProgressView("AI 변환/리믹스 중...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
                
                // === Voice Conversion 중 ProgressView ===
                if isVoiceConverting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("음성 변환 중...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text("최대 5분 정도 소요될 수 있습니다")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
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
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
            }
            .sheet(isPresented: $isPlaylistSelectSheetPresented, onDismiss: {
                libraryStore.send(.fetchUserPlaylists)
            }) {
                let playlists = ViewStore(libraryStore, observe: { $0.playlists }).state
                if let track = viewStore.currentTrack {
                    // PlaylistSelectSheet implementation would go here
                }
            }
            .alert("플레이리스트에 추가되었습니다!", isPresented: $showAddSuccess) {
                Button("확인", role: .cancel) { showAddSuccess = false }
            }
            
            // === 매칭 실패 Alert ===
            .alert("퍼블릭 도메인 곡을 찾을 수 없습니다.", isPresented: $showNoMatchAlert) {
                Button("확인", role: .cancel) { showNoMatchAlert = false }
            }
            
            // === Voice Conversion Error Alert ===
            .alert("음성 변환 실패", isPresented: $showVoiceConversionError) {
                Button("확인", role: .cancel) { showVoiceConversionError = false }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .sheet(isPresented: $showVoiceSelectionSheet) {
                VoiceSelectionSheet(
                    voices: availableVoices,
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
            .sheet(isPresented: $isAddToPlaylistSheetPresented) {
                AddToPlaylistSheet(
                    playlist: PlaylistSummaryDTO(
                        id: UUID(),
                        name: "Current Track",
                        user: nil
                    ),
                    onAdd: { _ in
                        // Handle adding current track to playlist
                        isAddToPlaylistSheetPresented = false
                    }
                )
            }
            .alert("음성 변환 오류", isPresented: $showVoiceConversionError) {
                Button("확인") { }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .overlay(
                Group {
                    if isVoiceConverting {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("음성을 변환하고 있습니다...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.top, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.7))
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Functions
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
    
    // MARK: - Helper Functions (Outside PlayerView)
    func remixDemoTrack(_ track: LocalDemoTrack, completion: @escaping (Result<URL, Error>) -> Void) {
        if let fileURL = Bundle.main.url(forResource: track.fileName, withExtension: nil) {
            uploadFileToAIConvert(fileURL: fileURL, completion: completion)
        } else {
            completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "내장 mp3 파일을 찾을 수 없습니다."])))
        }
    }
    
    func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let url = URL(string: "\(Endpoints.baseURL)/ai-convert/remix")! // AI 변환 엔드포인트
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        let filename = fileURL.lastPathComponent
        let mimetype = "audio/mpeg" // mp3 등 실제 파일 타입에 맞게

        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "파일을 읽을 수 없습니다."])))
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
            // 임시 파일로 저장
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
    
    @MainActor
    private func loadAvailableVoices() async {
        do {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw URLError(.badURL)
            }
            
            print("🎤 Loading available voices from: \(url)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            print("📡 Voice list response:")
            print("   Status code: \(httpResponse.statusCode)")
            print("   Response size: \(data.count) bytes")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response body: \(responseString)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            // 서버 응답을 직접 파싱하여 VoiceInfo 배열로 변환
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let voicesArray = json["voices"] as? [[String: Any]] {
                    // 서버에서 voices 배열로 반환하는 경우
                    availableVoices = voicesArray.compactMap { voiceDict in
                        guard let voiceId = voiceDict["voiceId"] as? String,
                              let name = voiceDict["name"] as? String,
                              let language = voiceDict["language"] as? [String],
                              let description = voiceDict["description"] as? String else {
                            return nil
                        }
                        
                        return VoiceInfo(
                            id: voiceId,
                            name: name,
                            category: language.first ?? "en",
                            description: description,
                            previewUrl: nil
                        )
                    }
                    
                    print("✅ Loaded \(availableVoices.count) voices successfully from voices array")
                } else if let availableVoicesArray = json["available_voices"] as? [String] {
                    // 기존 SeedVC API 형식
                    availableVoices = availableVoicesArray.map { voiceId in
                        VoiceInfo(
                            id: voiceId,
                            name: voiceId.replacingOccurrences(of: "-", with: " ").capitalized,
                            category: "SeedVC",
                            description: "Voice ID: \(voiceId)",
                            previewUrl: nil
                        )
                    }
                    
                    print("✅ Loaded \(availableVoices.count) voices successfully from available_voices array")
                } else {
                    throw URLError(.cannotParseResponse)
                }
            } else {
                throw URLError(.cannotParseResponse)
            }
            
        } catch {
            print("❌ Failed to load voices: \(error)")
            voiceConversionErrorMessage = "음성 목록을 불러오는데 실패했습니다: \(error.localizedDescription)"
            showVoiceConversionError = true
        }
    }
    
    // MARK: - Voice Conversion Functions
    private func loadVoices() {
        Task {
            do {
                let url = URL(string: "http://192.168.99.77:8081/ai-convert/voices")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("❌ Failed to load voices")
                    return
                }
                
                // Parse the response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let voicesArray = json["voices"] as? [[String: Any]] {
                    
                    let voices = voicesArray.compactMap { voiceDict -> VoiceInfo? in
                        guard let voiceId = voiceDict["voiceId"] as? String,
                              let name = voiceDict["name"] as? String,
                              let language = voiceDict["language"] as? [String],
                              let description = voiceDict["description"] as? String else {
                            return nil
                        }
                        
                        return VoiceInfo(
                            id: voiceId,
                            name: name,
                            category: language.first ?? "en",
                            description: description,
                            previewUrl: nil
                        )
                    }
                    
                    await MainActor.run {
                        self.availableVoices = voices
                        print("✅ Loaded \(voices.count) voices from Vapor server")
                    }
                }
            } catch {
                print("❌ Error loading voices: \(error)")
            }
        }
    }
    
    private func performVoiceConversion(with voice: VoiceInfo) {
        let currentTrack = audioManager.currentTrackMetadata
        guard currentTrack.title != nil || currentTrack.artist != nil else {
            showVoiceConversionError = true
            voiceConversionErrorMessage = "현재 재생 중인 트랙이 없습니다."
            return
        }
        
        isVoiceConverting = true
        
        Task {
            do {
                // Get the current audio file URL
                let audioURL: URL
                if let currentURL = audioManager.currentAudioURL {
                    audioURL = currentURL
                } else {
                    // Fallback to demo file if no current audio URL
                    guard let demoURL = Bundle.main.url(forResource: "fixyou", withExtension: "mp3") else {
                        throw VoiceConversionError.invalidAudioData
                    }
                    audioURL = demoURL
                }
                
                // Load audio data
                let audioData = try Data(contentsOf: audioURL)
                
                // Trim audio to 1 minute for "Fix You" track
                let trimmedAudioData: Data
                if currentTrack.title?.contains("Fix You") == true {
                    print("✂️ Trimming Fix You track to 1 minute")
                    trimmedAudioData = try await trimAudioToDuration(audioData, duration: 60.0)
                } else {
                    trimmedAudioData = audioData
                }
                
                // Perform voice conversion
                let convertedAudioData = try await performVaporServerVoiceConversion(
                    audioData: trimmedAudioData,
                    voiceId: voice.id,
                    originalTitle: currentTrack.title ?? "Unknown Track"
                )
                
                // Save converted audio
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "voice_converted_\(voice.name).mp3"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try convertedAudioData.write(to: fileURL)
                
                print("✅ Voice conversion successful, saved to: \(fileURL)")
                print("File size: \(convertedAudioData.count) bytes")
                print("File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                
                // Get audio duration
                let asset = AVAsset(url: fileURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                print("Audio duration: \(durationSeconds) seconds")
                
                // Update audio manager with converted track
                await MainActor.run {
                    Task {
                        try await audioManager.playAIMusic(
                            from: fileURL.path,
                            title: "\(currentTrack.title ?? "Unknown") (Voice: \(voice.name))",
                            artist: currentTrack.artist ?? "Unknown Artist"
                        )
                    }
                    
                    isVoiceConverting = false
                }
                
            } catch {
                await MainActor.run {
                    isVoiceConverting = false
                    showVoiceConversionError = true
                    voiceConversionErrorMessage = "음성 변환에 실패했습니다: \(error.localizedDescription)"
                    print("❌ AI music playback error: \(error)")
                }
            }
        }
    }
    
    private func performVaporServerVoiceConversion(
        audioData: Data,
        voiceId: String,
        originalTitle: String
    ) async throws -> Data {
        print("🎵 Starting voice conversion with Vapor server")
        print("Voice ID: \(voiceId)")
        print("Audio data size: \(audioData.count) bytes")
        
        let url = URL(string: "http://192.168.99.77:8081/ai-convert/voice-conversion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1800 // 30 minutes
        
        // Configure URLSession with longer timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1800 // 30 minutes
        config.timeoutIntervalForResource = 3600 // 60 minutes
        let session = URLSession(configuration: config)
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source_audio\"; filename=\"\(originalTitle).mp3\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add voice ID
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voiceId\"\r\n\r\n".data(using: .utf8)!)
        body.append(voiceId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add output format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"outputFormat\"\r\n\r\n".data(using: .utf8)!)
        body.append("mp3".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add use separation
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"useSeparation\"\r\n\r\n".data(using: .utf8)!)
        body.append("true".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("⏱️ Voice conversion may take up to 30 minutes. Please wait...")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceConversionError.serverError("Invalid response")
        }
        
        print("🔍 Voice conversion response: Status code: \(httpResponse.statusCode)")
        print("Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        print("Response size: \(data.count) bytes")
        print("Response headers: \(httpResponse.allHeaderFields)")
        
        // Check if response is JSON (error) or audio data
        if let responseString = String(data: data, encoding: .utf8),
           responseString.hasPrefix("{") {
            // This is a JSON error response
            print("First 10 bytes: \(Array(data.prefix(10)))")
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("JSON response keys: \(json.keys)")
                if let error = json["error"] as? String {
                    throw VoiceConversionError.serverError(error)
                } else if let success = json["success"] as? Bool, !success {
                    throw VoiceConversionError.serverError("Voice conversion failed")
                }
            }
            throw VoiceConversionError.invalidAudioData
        }
        
        // This is audio data
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw VoiceConversionError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    private func trimAudioToDuration(_ audioData: Data, duration: TimeInterval) async throws -> Data {
        print("✂️ Trimming audio to \(duration) seconds")
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.mp3")
        try audioData.write(to: tempURL)
        
        // Create asset
        let asset = AVAsset(url: tempURL)
        
        // Create export session with MP3 preset
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VoiceConversionError.invalidAudioData
        }
        
        // Set output URL
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed_audio.m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Set time range (0 to duration)
        let startTime = CMTime.zero
        let endTime = CMTime(seconds: duration, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        // Export
        await exportSession.export()
        
        // Check result
        guard exportSession.status == .completed else {
            print("❌ Export failed with status: \(exportSession.status.rawValue)")
            if let error = exportSession.error {
                print("Export error: \(error)")
            }
            throw VoiceConversionError.invalidAudioData
        }
        
        // Read trimmed data
        let trimmedData = try Data(contentsOf: outputURL)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: outputURL)
        
        print("✅ Audio trimmed successfully: \(trimmedData.count) bytes")
        return trimmedData
    }
}

// MARK: - Voice Selection Sheet
struct VoiceSelectionSheet: View {
    let voices: [VoiceInfo]
    let onVoiceSelected: (VoiceInfo) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    
    var filteredVoices: [VoiceInfo] {
        if searchText.isEmpty {
            return voices
        } else {
            return voices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
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
                
                // Search bar
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
                
                // Voice list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredVoices) { voice in
                            VoiceRowView(voice: voice) {
                                onVoiceSelected(voice)
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
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Voice icon
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
                    }
                    
                    if let description = voice.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Text(voice.category)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
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
