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
                .frame(width: 200, height: 200)
                .cornerRadius(10)
        } else {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 200, height: 200)
                .cornerRadius(10)
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
        HStack(spacing: 30) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(Color.purple)
            }
            
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(Color.purple)
            }
            
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(Color.purple)
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

// MARK: - Main Player View
struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    @Binding var isMiniPlayerVisible: Bool
    @State private var isDetailViewPresented = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var audioManager = AudioManager.shared
    
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
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
            VStack(spacing: 20) {
                AlbumArtView(albumArt: audioManager.currentTrackMetadata.albumArt)
                
                Text(audioManager.currentTrackMetadata.title ?? "No Track")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(audioManager.currentTrackMetadata.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                
                // Progress Slider
                if audioManager.duration > 0 {
                    Slider(value: $audioManager.currentTime, in: 0...audioManager.duration, onEditingChanged: { editing in
                        if !editing {
                            audioManager.seek(to: audioManager.currentTime)
                        }
                    })
                    .accentColor(Color.purple)
                } else {
                    Slider(value: .constant(0), in: 0...1)
                        .disabled(true)
                }
                
                // Time Labels
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    Spacer()
                    Text(formatTime(audioManager.duration))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                }
                
                PlayerControlsView(
                    isPlaying: viewStore.isPlaying,
                    onPrevious: { viewStore.send(.previousTrack) },
                    onPlayPause: { viewStore.send(.playPause) },
                    onNext: { viewStore.send(.nextTrack) }
                )
                
                Button(action: { isDetailViewPresented = true }) {
                    Text("Track List")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $isDetailViewPresented) {
                    PlayerDetailView(store: self.store)
                }
                
                AIMusicToggleView(
                    isAIPlaying: viewStore.isAIMusicEnabled,
                    onToggle: { viewStore.send(.toggleAIMusic($0)) }
                )
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
            }
            .gesture(DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 100 {
                        isMiniPlayerVisible = true
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
}
