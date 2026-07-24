//
//  PlaylistDetailView.swift
//  BeamApp
//
//  Created by anonymous on 5/13/25.
//

import SwiftUI
import Foundation

struct PlaylistDetailView: View {
    let playlist: PlaylistSummaryDTO
    let songs: [PlayableTrackDTO]
    let onPlayAll: () -> Void
    var onPlayTrack: ((PlayableTrackDTO) -> Void)? = nil
    var fetchSongs: ((@escaping ([PlayableTrackDTO]) -> Void) -> Void)? = nil
    @StateObject private var preConversionManager = PreConversionManager.shared
    @State private var isAddingSong = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showVoiceSelectionSheet = false
    @State private var selectedSongForConversion: PlayableTrackDTO?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var displaySongs: [PlayableTrackDTO] = []

    @ViewBuilder
    private var playlistContent: some View {
        if isLoading && !displaySongs.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if displaySongs.isEmpty {
            Spacer()
            Text("This playlist has no songs.")
                .foregroundColor(.gray)
                .font(.title3)
                .padding(.bottom, 16)
            Button(action: { isAddingSong = true }) {
                Label("Add Song", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            Spacer()
        } else {
            Button(action: onPlayAll) {
                Label("Play All", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 32)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 8)
            Button(action: { isAddingSong = true }) {
                Label("Add Song", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 8)

            let convertedTracks = preConversionManager.convertedTracks(for: displaySongs)
            if !convertedTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversion Library")
                        .font(.headline)
                    ForEach(convertedTracks) { track in
                        Button(action: { onPlayTrack?(track) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(track.artistName ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.purple)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            List {
                ForEach(displaySongs) { song in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artistName ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            if let status = preConversionManager.statusText(for: song) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(status)
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                    if let badge = preConversionManager.statusBadgeText(for: song) {
                                        Text(badge)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            HStack(spacing: 8) {
                                if let convertedTrack = preConversionManager.latestConvertedTrack(for: song) {
                                    Button("Play") {
                                        onPlayTrack?(convertedTrack)
                                    }
                                    .font(.caption)
                                }
                                Button("Convert") {
                                    selectedSongForConversion = song
                                    Task {
                                        await preConversionManager.loadAvailableVoices()
                                        showVoiceSelectionSheet = true
                                    }
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let song = displaySongs[index]
                        print("Attempting to delete song: \(song.title), playbackStoreID: \(song.playbackStoreID ?? "nil")")
                        if let _ = song.playbackStoreID {
                            deleteSong(song)
                        } else {
                            errorMessage = "This song cannot be deleted."
                        }
                    }
                }
                .onMove { indices, newOffset in
                    displaySongs.move(fromOffsets: indices, toOffset: newOffset)
                    let serverSongs = displaySongs.filter { $0.playbackStoreID != nil }
                    if !serverSongs.isEmpty {
                        updateSongOrderOnServer(with: serverSongs)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(playlist.name)
                .font(.largeTitle)
                .bold()
                .padding(.top, 32)
                .padding(.bottom, 16)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }

            playlistContent
        }
        .sheet(isPresented: $isAddingSong, onDismiss: {
            if let fetchSongs = fetchSongs {
                isLoading = true
                fetchSongs { loadedSongs in
                    DispatchQueue.main.async {
                        self.displaySongs = loadedSongs
                        self.isLoading = false
                    }
                }
            }
        }) {
            AddToPlaylistSheet(
                playlist: playlist,
                onAdd: { addedSong in
                    isAddingSong = false
                    if displaySongs.isEmpty {
                        let newTrack = PlayableTrackDTO(
                            id: UUID(),
                            title: addedSong.title,
                            artistName: addedSong.artist,
                            playbackUrl: nil,
                            playbackStoreID: addedSong.id,
                            isAIGenerated: false,
                            duration: 180.0,
                            fileUrl: nil,
                            artworkURL: addedSong.artworkURL
                        )
                        onPlayAll()
                    }
                }
            )
        }
        .padding(.horizontal)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("Delete this playlist?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePlaylist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear {
            isLoading = true
            preConversionManager.refreshConvertedRecords()

            if let fetchSongs = fetchSongs {
                fetchSongs { loadedSongs in
                    DispatchQueue.main.async {
                        self.displaySongs = loadedSongs
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.displaySongs = self.songs
                    self.isLoading = false
                }
            }
        }
        .onChange(of: songs) { _, newSongs in
            self.displaySongs = newSongs
            self.isLoading = false
        }
        .onChange(of: isLoading) { old, new in
            print("[DEBUG] isLoading changed: \(old) -> \(new)")
        }
        .onChange(of: displaySongs) { _, _ in
            if isLoading {
                isLoading = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showVoiceSelectionSheet) {
            VoiceSelectionSheet(
                voices: preConversionManager.availableVoices,
                onVoiceSelected: { voice, _ in
                    preConversionManager.setPreferredVoice(voice)
                    showVoiceSelectionSheet = false
                    guard let song = selectedSongForConversion else { return }
                    Task {
                        await preConversionManager.enqueue(track: song, voice: voice)
                    }
                },
                onCancel: {
                    showVoiceSelectionSheet = false
                }
            )
        }
    }

    private func deleteSong(_ song: PlayableTrackDTO) {
        errorMessage = nil
        guard let playlistID = playlist.id?.uuidString,
              let songID = song.playbackStoreID else {
            errorMessage = "Could not verify song information."
            return
        }
        let urlString = Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID) + "/\(songID)"
        guard let token = TokenStorage.shared.fetchToken() else {
            errorMessage = "No token found. Login required."
            return
        }
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    errorMessage = nil
                    if let fetchSongs = fetchSongs {
                        isLoading = true
                        fetchSongs { loadedSongs in
                            DispatchQueue.main.async {
                                self.displaySongs = loadedSongs
                                self.isLoading = false
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to delete song."
                }
            }
        }.resume()
    }

    private func deletePlaylist() {
        guard let playlistID = playlist.id?.uuidString else {
            errorMessage = "Could not verify playlist information."
            return
        }
        guard let token = TokenStorage.shared.fetchToken() else {
            errorMessage = "No token found. Login required."
            return
        }
        isDeleting = true
        let urlString = Endpoints.Playlist.userPlaylist + "/\(playlistID)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isDeleting = false
            }
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    errorMessage = nil
                    dismiss()
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to delete playlist."
                }
            }
        }.resume()
    }

    private func updateSongOrderOnServer(with songs: [PlayableTrackDTO]) {
        guard let playlistID = playlist.id?.uuidString else { return }
        let orderedSongIDs = songs.map { $0.id.uuidString }
        guard let token = TokenStorage.shared.fetchToken() else { return }
        let urlString = "\(Endpoints.Playlist.userPlaylist)/order/\(playlistID)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "orderedSongIDs": orderedSongIDs,
            "currentOrder": songs.enumerated().map { index, song in
                [
                    "id": song.id.uuidString,
                    "title": song.title,
                    "order": index,
                    "playbackStoreID": song.playbackStoreID ?? ""
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
          
            request.httpBody = jsonData
        } catch {
            print("[DEBUG] Failed to serialize request body: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to update song order: \(error.localizedDescription)"
                }
            } else if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    if let fetchSongs = fetchSongs {
                        DispatchQueue.main.async {
                            self.isLoading = true
                        }
                        fetchSongs { loadedSongs in
                            DispatchQueue.main.async {
                                var orderedSongs: [PlayableTrackDTO] = []
                                for id in orderedSongIDs {
                                    if let song = loadedSongs.first(where: { $0.id.uuidString == id }) {
                                        orderedSongs.append(song)
                                    }
                                }
                                self.displaySongs = orderedSongs
                                self.isLoading = false
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
}
