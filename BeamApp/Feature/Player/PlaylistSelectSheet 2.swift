//
//  PlaylistSelectSheet 2.swift
//  BeamApp
//
//  Created by anonymous on 6/9/25.
//


import SwiftUI

struct PlaylistSelectSheet: View {
    let playlists: [PlaylistSummaryDTO]
    let onSelect: (PlaylistSummaryDTO) -> Void
    let onCancel: () -> Void
    var body: some View {
        NavigationView {
            List(playlists) { playlist in
                Button(action: { onSelect(playlist) }) {
                    Text(playlist.name)
                        .font(.headline)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Select Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
