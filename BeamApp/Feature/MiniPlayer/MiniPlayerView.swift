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
        let displayTitle = viewStore.currentTrack?.title ?? audioManager.currentTrackMetadata.title

        if let title = displayTitle, !title.isEmpty, title != "No Track" {
            let artist = viewStore.currentTrack?.artistName ?? audioManager.currentTrackMetadata.artist ?? "Unknown Artist"
            VStack {
                HStack {
                    albumArtView
                    trackInfoView(title: title, artist: artist)
                    Spacer()
                    playPauseButton
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .onTapGesture {
                    isPlayerViewVisible = true
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color.gray.opacity(0.18))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1),
                alignment: .top
            )
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
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 50, height: 50)
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .cornerRadius(5)
            }
        }
    }

    private func trackInfoView(title: String, artist: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .lineLimit(1)

            Text(artist)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
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
