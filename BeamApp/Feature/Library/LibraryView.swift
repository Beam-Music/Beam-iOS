//
//  LibraryView.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import SwiftUI
import ComposableArchitecture
import Foundation

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
    @State private var fetchSongsCompletion: (([PlayableTrackDTO]) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 별 필드 뷰
                StarFieldView(starCount: 40, scrollOffset: scrollOffset)
                
                // 메인 콘텐츠
                mainContentView
            }
        }
        .navigationDestination(item: $selectedPlaylist) { playlist in
            playlistDetailDestination(playlist: playlist)
        }
        .onChange(of: store.state.selectedPlaylistSongsVersion) { _, _ in
            // 플레이리스트 곡이 로드되면 콜백 실행
            if let completion = fetchSongsCompletion {
                completion(store.state.selectedPlaylistSongs)
                fetchSongsCompletion = nil
            }
        }
    }
    
    // 메인 콘텐츠 뷰로 분리
    private var mainContentView: some View {
        VStack(spacing: 20) {
            // 에러 메시지 표시
            if let errorMessage = store.state.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                // 플레이리스트 목록 표시
                playlistListView()
            }
        }
        .onAppear {
            store.send(.fetchUserPlaylists)
        }
        .onChange(of: store.state.playlist) { _, newPlaylist in
            isMiniPlayerVisible = !newPlaylist.isEmpty
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    store.send(.showCreatePlaylistSheet(true))
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { store.state.isPresentingCreateSheet },
                set: { store.send(.showCreatePlaylistSheet($0)) }
            )
        ) {
            CreatePlaylistSheet(viewStore: ViewStore(store, observe: { $0 }))
        }
    }

    @ViewBuilder
    private func playlistDetailDestination(playlist: PlaylistSummaryDTO) -> some View {
        PlaylistDetailView(
            playlist: playlist,
            songs: store.state.selectedPlaylistSongs,
            onPlayAll: {
                store.send(.playAllInPlaylist)
            },
            fetchSongs: { completion in
                fetchSongsCompletion = completion
                store.send(.fetchPlaylistSongs(playlist))
            }
        )
    }

    private func playlistListView() -> some View {
        List {
            ForEach(store.state.playlists) { playlist in
                PlaylistRow(playlist: playlist) {
                    selectedPlaylist = playlist
                    store.send(.selectPlaylist(playlist))
                }
            }
            .onDelete { indexSet in
                store.send(.deletePlaylist(indexSet))
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