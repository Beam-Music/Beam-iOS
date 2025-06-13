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
        if let currentTrackTitle = audioManager.currentTrackMetadata.title,
           currentTrackTitle != "No Track" {
            VStack {
                HStack {
                    albumArtView
                    trackInfoView
                    Spacer()
                    playPauseButton
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
        } else {
            EmptyView()
        }
    }
    
    private var albumArtView: some View {
        Group {
            if let albumArt = audioManager.currentTrackMetadata.albumArt {
                Image(uiImage: albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .cornerRadius(5)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 50, height: 50)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .cornerRadius(5)
            }
        }
    }
    
    private var trackInfoView: some View {
        VStack(alignment: .leading) {
            Text(audioManager.currentTrackMetadata.title ?? "")
                .font(.headline)
                .lineLimit(1)
            
            Text(audioManager.currentTrackMetadata.artist ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.leading, 10)
    }
    
    private var playPauseButton: some View {
        Button(action: {
            Task {
                await playPause()
            }
        }) {
            Image(systemName: audioManager.isPlayingMusic ? "pause.fill" : "play.fill")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .padding(.trailing, 16)
    }
    
    private func playPause() async {
        if audioManager.isPlayingMusic {
            await audioManager.pause()
        } else {
            await audioManager.play()
        }
    }
}
