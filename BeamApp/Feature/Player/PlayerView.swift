//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

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
                Text("AI 음악 모드")
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
                Text("AI가 생성한 음악을 재생합니다")
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

// MARK: - Custom Remix/AI Toggle (Figma 스타일)
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
                        Text("오리지널")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    } else {
                        Text("AI 버전")
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
                    TextField("아티스트 검색", text: $searchText)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                    Spacer()
                    Button("완료") {
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

// MARK: - Main Player View
struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    @Binding var isMiniPlayerVisible: Bool
    @State private var isDetailViewPresented = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var isRemixSheetPresented = false
    @State private var selectedArtists: [Artist] = []
    let mockArtists: [Artist] = [
        Artist(name: "Dua Lipa", imageName: "artist_dualipa"),
        Artist(name: "BlackPink", imageName: "artist_blackpink"),
        Artist(name: "H.E.R", imageName: "artist_her"),
        Artist(name: "Rihanna", imageName: "artist_rihanna")
    ]
    
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
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                    startPoint: .top, endPoint: .bottom
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
                        AlbumArtView(albumArt: audioManager.currentTrackMetadata.albumArt)
                            .frame(width: 320, height: 320)
                            .cornerRadius(24)
                            .shadow(radius: 14)
                            .padding(.bottom, 8)
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
                                Button(action: {/* TODO: Add */}) {
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
                    HStack(spacing: 18) {
                        Button(action: { isRemixSheetPresented = true }) {
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
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                if isRemixSheetPresented {
                    RemixArtistPickerView(isPresented: $isRemixSheetPresented, selectedArtists: $selectedArtists, allArtists: mockArtists)
                        .transition(.move(edge: .bottom))
                        .zIndex(10)
                }
            }
            .onAppear {
                viewStore.send(.syncPlaybackState)
                if !viewStore.isPlaying {
                    viewStore.send(.playPause)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
