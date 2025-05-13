//
//  LibraryView.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import SwiftUI
import ComposableArchitecture
import Foundation

// 별 데이터 모델, StarFieldView, ScrollOffsetPreferenceKey가 HomeView.swift에 있다면 import해서 사용하거나, 중복 정의를 피하세요.
// 여기서는 예시로 별 관련 코드가 이미 프로젝트에 있다고 가정합니다.

struct PlaylistRow: View {
    let playlist: PlaylistSummaryDTO
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Text(playlist.name)
            Spacer()
            Button(action: onSelect) {}
        }
        .padding()
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct CreatePlaylistSheet: View {
    let viewStore: ViewStoreOf<LibraryReducer>

    var body: some View {
        VStack(spacing: 24) {
            Text("새 플레이리스트 만들기")
                .font(.headline)
            TextField("이름 입력", text: viewStore.binding(
                get: \.newPlaylistName,
                send: LibraryReducer.Action.updateNewPlaylistName
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            if viewStore.isCreatingPlaylist {
                ProgressView()
            } else {
                Button("생성하기") {
                    viewStore.send(.createPlaylist)
                }
                .disabled(viewStore.newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let error = viewStore.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .padding()
    }
}

struct LibraryView: View {
    let store: StoreOf<LibraryReducer>
    @Binding var isMiniPlayerVisible: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedPlaylist: PlaylistSummaryDTO? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                StarFieldView(starCount: 40, scrollOffset: scrollOffset)
                WithViewStore(self.store, observe: { $0 }) { viewStore in
                    let createSheetBinding = viewStore.binding(
                        get: \.isPresentingCreateSheet,
                        send: LibraryReducer.Action.showCreatePlaylistSheet
                    )
                    VStack(spacing: 20) {
                        if let errorMessage = viewStore.errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                        } else {
                            playlistListView(viewStore: viewStore)
                        }
                    }
                    .onAppear {
                        viewStore.send(.fetchUserPlaylists)
                    }
                    .onChange(of: viewStore.playlist) { _ in
                        isMiniPlayerVisible = !viewStore.playlist.isEmpty
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { viewStore.send(.showCreatePlaylistSheet(true)) }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                            }
                        }
                    }
                    .sheet(isPresented: createSheetBinding) {
                        CreatePlaylistSheet(viewStore: viewStore)
                    }
                    .navigationDestination(item: $selectedPlaylist) { playlist in
                        PlaylistDetailView(
                            playlist: playlist,
                            songs: viewStore.selectedPlaylistSongs,
                            onPlayAll: { viewStore.send(.playAllInPlaylist) },
                            fetchSongs: { viewStore.send(.fetchPlaylistSongs(playlist)) }
                        )
                    }
                }
            }
        }
    }

    private func playlistListView(viewStore: ViewStoreOf<LibraryReducer>) -> some View {
        List {
            ForEach(viewStore.playlists) { playlist in
                PlaylistRow(playlist: playlist) {
                    selectedPlaylist = playlist
                    viewStore.send(.selectPlaylist(playlist))
                }
            }
            .onDelete { indexSet in
                viewStore.send(.deletePlaylist(indexSet))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }
}
