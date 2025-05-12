//
//  AddToPlaylist.swift
//  BeamApp
//
//  Created by anonymous on 5/12/25.
//

import SwiftUI
import ComposableArchitecture
import Foundation

struct AddToPlaylistSheet: View {
    let currentTrack: PlayableTrackDTO?
    let store: StoreOf<LibraryReducer>
    let onAdd: (PlaylistSummaryDTO) -> Void

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack {
                    if viewStore.playlists.isEmpty {
                        Spacer()
                        Text("보유 중인 재생목록이 없습니다.")
                            .font(.headline)
                            .padding()
                        Spacer()
                    } else {
                        List(viewStore.playlists) { playlist in
                            Button(action: {
                                guard let playlistID = playlist.id?.uuidString, let songID = currentTrack?.playbackStoreID else { return }
                                let urlString = Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID)
                                guard let token = TokenStorage.shared.fetchToken() else {
                                    print("토큰이 없습니다. 로그인 필요")
                                    return
                                }
                                let body: [String: String] = [
                                    "songId": songID,
                                    "title": currentTrack?.title ?? "",
                                    "artistName": currentTrack?.artistName ?? ""
                                ]
                                print("플레이리스트ID: \(playlistID), 곡ID: \(songID), title: \(currentTrack?.title ?? ""), artist: \(currentTrack?.artistName ?? "")")
                                addSongToPlaylist(urlString: urlString, body: body, token: token) { result in
                                    DispatchQueue.main.async {
                                        switch result {
                                        case .success:
                                            print("곡이 재생목록에 추가되었습니다!")
                                            onAdd(playlist)
                                        case .failure(let error):
                                            print("추가 실패: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }) {
                                Text(playlist.name)
                            }
                        }
                    }
                }
                .navigationTitle("재생목록에 추가")
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                viewStore.send(.fetchUserPlaylists)
            }
        }
    }
}

func addSongToPlaylist(urlString: String, body: [String: String], token: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0)))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(NSError(domain: "No HTTPURLResponse", code: 0)))
            return
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
            print("서버 에러 응답: \(errorBody)")
            completion(.failure(NSError(domain: "Server error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorBody])))
            return
        }
        completion(.success(()))
    }.resume()
} 
