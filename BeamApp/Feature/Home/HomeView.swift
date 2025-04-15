//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

// MARK: - Playlist Row View
struct PlaylistRowView: View {
    let playlist: PlaylistSummaryDTO
    let onPlayTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
            Button(action: onPlayTapped) {
                Image(systemName: "play.fill")
                    .foregroundColor(Color.purple)
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

// MARK: - Navigation Bar View
struct HomeNavigationBarView: View {
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        NavigationLink(destination: SettingsView(isLoggedIn: $isLoggedIn)) {
            Image(systemName: "gearshape")
                .font(.system(size: 20))
                .foregroundColor(Color.purple)
        }
    }
}

// MARK: - Playlist List View
struct PlaylistListView: View {
    let playlists: [PlaylistSummaryDTO]
    let onPlaylistSelected: (PlaylistSummaryDTO) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List(playlists, id: \.id) { playlist in
            PlaylistRowView(
                playlist: playlist,
                onPlayTapped: { onPlaylistSelected(playlist) }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<HomeReducer>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 12) {
                    PlaylistListView(
                        playlists: viewStore.recommendedPlaylists,
                        onPlaylistSelected: { playlist in
                            viewStore.send(.selectPlaylist(playlist))
                            isMiniPlayerVisible = true
                        }
                    )
                }
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
                .navigationBarItems(trailing: HomeNavigationBarView(isLoggedIn: $isLoggedIn))
                .onAppear {
                    viewStore.send(.fetchUserPlaylists)
                    viewStore.send(.fetchRecommendPlaylists)
                    if let selectedPlaylistID = viewStore.selectedPlaylistID {
                        viewStore.send(.fetchPlaylist(selectedPlaylistID))
                        viewStore.send(.fetchRecommendPlaylistSongs(selectedPlaylistID))
                    }
                }
                .onChange(of: viewStore.playlist) { _ in
                    isMiniPlayerVisible = !viewStore.playlist.isEmpty
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
    }
}


//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(isLoggedIn: .constant(true))
//    }
//}
