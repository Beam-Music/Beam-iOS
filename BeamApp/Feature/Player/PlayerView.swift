//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct PlayerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    let store: StoreOf<PlayerReducer>
    @Binding var isMiniPlayerVisible: Bool
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                if let albumArt = audioManager.currentTrackMetadata.albumArt {
                    Image(uiImage: albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 200, height: 200)
                        .cornerRadius(10)
                }
                Text(audioManager.currentTrackMetadata.title ?? "No Track")
                    .font(.headline)
                
                Text(audioManager.currentTrackMetadata.artist ?? "Unknown Artist")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if audioManager.duration > 0 {
                    Slider(value: $audioManager.currentTime, in: 0...audioManager.duration, onEditingChanged: { editing in
                        if !editing {
                            audioManager.seek(to: audioManager.currentTime)
                        }
                    })
                    .accentColor(.white)
                } else {
                    Slider(value: .constant(0), in: 0...1)
                        .disabled(true)
                }
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                    Spacer()
                    Text(formatTime(audioManager.duration))
                }
                
                HStack(spacing: 30) {
                    Button(action: { viewStore.send(.previousTrack) }) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    
                    Button(action: playPause) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                    
                    Button(action: { viewStore.send(.nextTrack) }) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                }
                .foregroundColor(.gray)
            }
            .padding()
            .onChange(of: viewStore.playlist) { _ in
                //                playCurrentTrack(viewStore: viewStore)
            }
            .onAppear {
                // page 로드 될 때 자동재생 필요하면
                //                playCurrentTrack(viewStore: viewStore)
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
    
    private func playPause() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
    
    private func playCurrentTrack(viewStore: ViewStore<PlayerReducer.State, PlayerReducer.Action>) {
        guard !viewStore.playlist.isEmpty, viewStore.currentIndex >= 0, viewStore.currentIndex < viewStore.playlist.count else {
            print("Error: Index out of range or empty playlist")
            return
        }
        
        let currentTrack = viewStore.playlist[viewStore.currentIndex]
        print(currentTrack, "track check")
        Task {
            do {
                await audioManager.playAppleMusicTrack(with: currentTrack.title)
            } catch {
                print("Failed to play track: \(error)")
            }
        }
    }
}
