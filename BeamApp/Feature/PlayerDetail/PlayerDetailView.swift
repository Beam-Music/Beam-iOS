//
//  PlayerDetailView.swift
//  BeamApp
//
//  Created by freed on 10/24/24.
//

import SwiftUI
import ComposableArchitecture

struct PlayerDetailView: View {
    let store: StoreOf<PlayerReducer>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                Text("Now Playing")
                    .font(.title2)
                    .padding()
                
                if let currentTrack = viewStore.playlist[safe: viewStore.currentIndex] {
                    HStack {
                        Text(currentTrack.title)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                } else {
                    Text("No track playing")
                }
                
                Divider()
                
                Text("Up Next")
                    .font(.title2)
                    .padding()
                
                List {
                    ForEach(Array(viewStore.playlist.dropFirst(viewStore.currentIndex + 1)), id: \.id) { (track: PlayableTrackDTO) in
                        HStack {
                            Text(track.title)
                                .font(.headline)
                            Spacer()
                            Text(track.artistName ?? "Unknown Artist") // <- artistName 사용
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
