//
//  MiniPlayerView.swift
//  BeamApp
//
//  Created by freed on 10/11/24.
//
import SwiftUI
import ComposableArchitecture

struct MiniPlayerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    let store: StoreOf<PlayerReducer>
    @Binding var isPlayerViewVisible: Bool
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            if let currentTrackTitle = audioManager.currentTrackMetadata.title, currentTrackTitle != "No Track" {
                VStack {
                    HStack {
                        if let albumArt = audioManager.currentTrackMetadata.albumArt {
                            Image(uiImage: albumArt)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .cornerRadius(5)
                        } else {
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 50, height: 50)
                                .cornerRadius(5)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(currentTrackTitle)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text(audioManager.currentTrackMetadata.artist ?? "Unknown Artist")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .padding(.leading, 10)
                        
                        Spacer()
                        
                        Button(action: {
                            playPause()
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .padding(.trailing, 16)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .onTapGesture {
                        isPlayerViewVisible = true
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color.black.opacity(0.9))
            }
        }
    }
    
    private func playPause() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
}

