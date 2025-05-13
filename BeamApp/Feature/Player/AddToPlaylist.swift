//
//  AddToPlaylist.swift
//  BeamApp
//
//  Created by anonymous on 5/12/25.
//

import SwiftUI
import ComposableArchitecture
import Foundation
import MusicKit

struct AddToPlaylistSheet: View {
    let playlist: PlaylistSummaryDTO
    let onAdd: () -> Void

    @State private var searchText: String = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("노래/가수 검색하기", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .focused($isTextFieldFocused)
                        .onSubmit { searchSongs() }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                if isLoading {
                    ProgressView()
                        .padding()
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if !searchResults.isEmpty {
                    List(searchResults) { result in
                        Button(action: {
                            addSongToPlaylist(result: result)
                        }) {
                            HStack(spacing: 12) {
                                if let url = result.artworkURL {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(8)
                                } else {
                                    Image(systemName: "music.note")
                                        .foregroundColor(.gray)
                                        .background(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(result.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        if result.isExplicit {
                                            Text("E")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.5))
                                                .cornerRadius(3)
                                        }
                                    }
                                    Text(result.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else if !searchText.isEmpty {
                    Text("검색 결과가 없습니다.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    Text("노래를 검색해 추가하세요.")
                        .foregroundColor(.gray)
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("노래 추가")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                searchSongs()
            } else {
                searchResults = []
            }
        }
    }

    func searchSongs() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let results = try await MusicSearchService().searchMusic(query: searchText)
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func addSongToPlaylist(result: MusicSearchResult) {
        guard let playlistID = playlist.id?.uuidString else {
            errorMessage = "플레이리스트 정보가 올바르지 않습니다."
            return
        }
        let urlString = Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID)
        guard let token = TokenStorage.shared.fetchToken() else {
            errorMessage = "토큰이 없습니다. 로그인 필요"
            return
        }
        let body: [String: String] = [
            "songId": result.id,
            "title": result.title,
            "artistName": result.artist
        ]
        isLoading = true
        addSongToPlaylistAPI(urlString: urlString, body: body, token: token) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    onAdd()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

func addSongToPlaylistAPI(urlString: String, body: [String: String], token: String, completion: @escaping (Result<Void, Error>) -> Void) {
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
