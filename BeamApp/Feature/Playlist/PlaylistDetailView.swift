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
    var fetchSongs: ((@escaping ([PlayableTrackDTO]) -> Void) -> Void)? = nil
    @State private var isAddingSong = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var displaySongs: [PlayableTrackDTO] = []

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

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if displaySongs.isEmpty {
                Spacer()
                Text("이 플레이리스트에 노래가 없습니다.")
                    .foregroundColor(.gray)
                    .font(.title3)
                    .padding(.bottom, 16)
                Button(action: { isAddingSong = true }) {
                    Label("노래 추가하기", systemImage: "plus")
                        .font(.headline)
                        .padding()
                        .background(Color.purple.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Spacer()
            } else {
                // Fixed line 94 - proper call to onPlayAll closure
                Button(action: onPlayAll) {
                    Label("전체 재생", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 32)
                        .background(Color.purple.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.bottom, 8)
                List {
                    ForEach(displaySongs) { song in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artistName ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let song = displaySongs[index]
                            print("삭제 시도 곡: \(song.title), playbackStoreID: \(song.playbackStoreID ?? "nil")")
                            if let _ = song.playbackStoreID {
                                deleteSong(song)
                            } else {
                                errorMessage = "이 곡은 삭제할 수 없습니다."
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $isAddingSong, onDismiss: {
            // 곡 추가 시트가 닫힐 때 플레이리스트 데이터 다시 로드
            print("Sheet dismissed, reloading songs")
            if let fetchSongs = fetchSongs {
                isLoading = true
                fetchSongs { loadedSongs in
                    DispatchQueue.main.async {
                        self.displaySongs = loadedSongs
                        self.isLoading = false
                        print("Songs reloaded after sheet dismissal: \(loadedSongs.count)")
                    }
                }
            }
        }) {
            AddToPlaylistSheet(
                playlist: playlist,
                onAdd: {
                    isAddingSong = false
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
        .alert("플레이리스트를 삭제하시겠습니까?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                deletePlaylist()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
        .onAppear {
            isLoading = true
            print("PlaylistDetailView appeared, loading songs for playlist: \(playlist.name)")
            
            if let fetchSongs = fetchSongs {
                fetchSongs { loadedSongs in
                    DispatchQueue.main.async {
                        self.displaySongs = loadedSongs
                        self.isLoading = false
                        print("Songs loaded: \(loadedSongs.count), setting isLoading to false")
                    }
                }
            } else {
                // 초기화 시 전달된 songs로 설정
                DispatchQueue.main.async {
                    self.displaySongs = self.songs
                    self.isLoading = false
                    print("No fetchSongs provided, using initial songs: \(self.songs.count), setting isLoading to false")
                }
            }
            print(playlist.id?.uuidString ?? "nil", "playlistID", TokenStorage.shared.fetchToken() ?? "nil", "token")
        }
    }

    private func deleteSong(_ song: PlayableTrackDTO) {
        errorMessage = nil
        guard let playlistID = playlist.id?.uuidString,
              let songID = song.playbackStoreID else {
            errorMessage = "곡 정보를 확인할 수 없습니다."
            return
        }
        let urlString = Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID) + "/\(songID)"
        guard let token = TokenStorage.shared.fetchToken() else {
            errorMessage = "토큰이 없습니다. 로그인 필요"
            return
        }
        var request = URLRequest(url: URL(string: urlString)!)
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
                    // 노래 삭제 후 플레이리스트 데이터 다시 로드
                    if let fetchSongs = fetchSongs {
                        isLoading = true
                        fetchSongs { loadedSongs in
                            DispatchQueue.main.async {
                                self.displaySongs = loadedSongs
                                self.isLoading = false
                                print("Songs reloaded after deletion: \(loadedSongs.count)")
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "노래 삭제에 실패했습니다."
                }
            }
        }.resume()
    }

    private func deletePlaylist() {
        guard let playlistID = playlist.id?.uuidString else {
            errorMessage = "플레이리스트 정보를 확인할 수 없습니다."
            return
        }
        guard let token = TokenStorage.shared.fetchToken() else {
            errorMessage = "토큰이 없습니다. 로그인 필요"
            return
        }
        isDeleting = true
        let urlString = Endpoints.Playlist.userPlaylist + "/\(playlistID)"
        var request = URLRequest(url: URL(string: urlString)!)
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
                    errorMessage = "플레이리스트 삭제에 실패했습니다."
                }
            }
        }.resume()
    }
}