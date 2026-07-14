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
        Button(action: onSelect) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.primaryAccent.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

                Text(playlist.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(AppTheme.Spacing.md)
            .beamCard(cornerRadius: AppTheme.Radius.md, fillOpacity: 0.08)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open playlist \(playlist.name)")
        .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct CreatePlaylistSheet: View {
    let viewStore: ViewStoreOf<LibraryReducer>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Create Playlist")
                        .font(.title2.weight(.bold))
                    Text("Name it clearly so it is easy to find later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("Playlist name", text: viewStore.binding(
                    get: \.newPlaylistName,
                    send: LibraryReducer.Action.updateNewPlaylistName
                ))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)

                if let error = viewStore.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(error)")
                }

                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewStore.send(.createPlaylist)
                    } label: {
                        if viewStore.isCreatingPlaylist {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(viewStore.newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty || viewStore.isCreatingPlaylist)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct LibraryView: View {
    let store: StoreOf<LibraryReducer>
    @Binding var isMiniPlayerVisible: Bool
    @StateObject private var preConversionManager = PreConversionManager.shared
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedPlaylist: PlaylistSummaryDTO? = nil
    @State private var fetchSongsCompletion: (([PlayableTrackDTO]) -> Void)? = nil
    @State private var showConvertedTracks = false

    // Debugging: selectedPlaylist change tracking
    private func debugSelectedPlaylistChange(_ old: PlaylistSummaryDTO?, _ new: PlaylistSummaryDTO?) {
        print("[DEBUG] selectedPlaylist changed: \(String(describing: old?.name)) -> \(String(describing: new?.name))")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                BeamScreenBackground()
                
                // Star field view
                StarFieldView(starCount: 28, scrollOffset: scrollOffset)
                    .opacity(0.42)
                
                // Main content
                mainContentView
            }
        }
        .navigationDestination(item: $selectedPlaylist) { playlist in
            playlistDetailDestination(playlist: playlist)
        }
        .navigationDestination(isPresented: $showConvertedTracks) {
            ConvertedTracksView(
                onPlayTrack: { track in
                    store.send(.startPlayback([track]))
                }
            )
        }
        .onChange(of: store.state.selectedPlaylistSongs) { oldSongs, newSongs in
           
            if let completion = fetchSongsCompletion, oldSongs != newSongs {
                completion(newSongs)
                fetchSongsCompletion = nil
            }
        }
        .onChange(of: selectedPlaylist, debugSelectedPlaylistChange)
        .onDisappear {
            fetchSongsCompletion = nil
        }
    }
    
    // Separated into the main content view
    private var mainContentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    BeamSectionHeader(
                        title: "Library",
                        subtitle: "Your playlists and converted tracks",
                        actionTitle: nil,
                        action: nil
                    )

                    // Songs I Converted 플레이리스트
                    Button(action: { showConvertedTracks = true }) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "waveform")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(AppTheme.primaryAccent, in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text("Songs I Converted")
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                let count = ConvertedVoiceTrackStore.load().count
                                Text("\(count) songs")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(AppTheme.Spacing.md)
                        .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.08)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Show error message
                    if let errorMessage = store.state.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }

                    // Show playlist list
                    playlistListView()
                }
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, 104)
            }
        }
        .onAppear {
            preConversionManager.refreshConvertedRecords()
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
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Create playlist")
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
            onPlayTrack: { track in
                store.send(.startPlayback([track]))
            },
            fetchSongs: { [weak store] completion in
                if fetchSongsCompletion != nil {
                    fetchSongsCompletion = nil
                }
                fetchSongsCompletion = completion
                DispatchQueue.main.async {
                    if let store = store, selectedPlaylist?.id == playlist.id {
                        store.send(.fetchPlaylistSongs(playlist))
                    } else {
                        print("store.send skipped: View is not visible or store is nil")
                    }
                }
            }
        )
    }

    private func convertedTracksSection(_ tracks: [PlayableTrackDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Converted Songs")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showConvertedTracks = true }) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tracks) { track in
                        Button(action: {
                            store.send(.startPlayback([track]))
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(track.title)
                                    .font(.subheadline.bold())
                                    .lineLimit(2)
                                    .foregroundColor(.white)
                                Text(track.artistName ?? "")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
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
        .frame(minHeight: 220)
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

struct ConvertedTracksView: View {
    let onPlayTrack: (PlayableTrackDTO) -> Void

    @State private var tracks: [ConvertedVoiceTrackRecord] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.mainGradient.ignoresSafeArea()

            if tracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No converted songs")
                        .foregroundColor(.white.opacity(0.7))
                    Text("Converted songs will appear here")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                List {
                    ForEach(tracks) { record in
                        Button(action: {
                            onPlayTrack(record.toPlayableTrack())
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                                        .font(.body.bold())
                                        .foregroundColor(.white)
                                    Text(record.artistName ?? "Unknown")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Text(record.voiceName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    ConvertedVoiceTrackStore.delete(id: record.id)
                                    tracks.removeAll { $0.id == record.id }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Converted Songs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tracks = ConvertedVoiceTrackStore.load()
        }
    }
}
