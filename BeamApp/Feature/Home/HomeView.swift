//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture


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
    
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""
   
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
               
                HStack {
                    TextField("노래/가수 검색하기", text: $searchText)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                        )
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .medium))
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                Spacer()
                HStack {
                    Spacer(minLength: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 1, y: 2)
                    )
                    .padding(.leading, 24)
                    Spacer()
                }
                Spacer()
                
            }
        }
    }
}


//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(isLoggedIn: .constant(true))
//    }
//}
