//
//  HomeFeature.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//


import SwiftData
import Foundation

struct HomeFeature {
    static func fetchToken(context: ModelContext) async throws -> String {
        let tokenStorage = TokenStorage(context: context)
        guard let token = tokenStorage.fetchToken() else {
            throw NSError(domain: "No Token Found", code: 401, userInfo: nil)
        }
        return token
    }
    
    static func fetchUserPlaylists(with token: String) async throws -> [UserPlaylist] {
        var request = URLRequest(url: URL(string: "http://192.168.0.19:8080/user-playlists")!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        let userPlaylists = try JSONDecoder().decode([UserPlaylist].self, from: data)
        return userPlaylists
    }
    
    static func fetchPlaylist(with token: String, playlistID: String) async throws -> [PlaylistTrack] {
        var request = URLRequest(url: URL(string: "http://192.168.0.19:8080/user-playlists/\(playlistID)/songs")!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("Requesting playlist with token: Bearer \(token)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        do {
            let playlist = try JSONDecoder().decode([PlaylistTrack].self, from: data)
            print(playlist, "playlist check")
            return playlist
        } catch let decodingError as DecodingError {
            print("Failed to decode JSON: \(decodingError)")
            throw decodingError
        } catch {
            print("Unexpected error: \(error)")
            throw error
        }
    }
}
