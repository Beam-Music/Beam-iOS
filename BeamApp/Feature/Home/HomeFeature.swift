//
//  HomeFeature.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//
import SwiftData
import Foundation
import MusicKit

struct RegisterAISongRequestDTO: Codable {
    let title: String
    let fileName: String
    let genre: String?
    let duration: Int?
    // let artistName: String?
}

struct HomeFeature {
    static func fetchToken(context: ModelContext) async throws -> String {
        guard let token = await TokenStorage.shared.fetchToken() else {
            throw NSError(domain: "No Token Found", code: 401, userInfo: nil)
        }
        return token
    }
    
    static func fetchUserPlaylists(with token: String) async throws -> [PlaylistSummaryDTO] {
        var request = URLRequest(url: URL(string: Endpoints.Playlist.userPlaylist)!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid Response", code: httpResponse.statusCode, userInfo: nil)
        }
        
        let userPlaylists = try JSONDecoder().decode([PlaylistSummaryDTO].self, from: data)
        return userPlaylists
    }
    
    static func fetchPlayableAISongs(with token: String) async throws -> [PlayableTrackDTO] {
        guard let url = URL(string: Endpoints.AISong.playable) else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid playable AI songs endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 0, userInfo: [NSLocalizedDescriptionKey: "Did not receive HTTPURLResponse"])
        }
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch playable AI songs. Status: \(httpResponse.statusCode)",
                "responseBody": responseBody
            ])
        }
        
        return try JSONDecoder().decode([PlayableTrackDTO].self, from: data)
    }
    
    static func registerNewAISong(
        with token: String,
        title: String,
        fileName: String,
        genre: String?,
        duration: Int?
        // artistName: String? // 필요시 추가
    ) async throws -> Song {
        guard let url = URL(string: Endpoints.AISong.register) else {
            throw NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid registration endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = RegisterAISongRequestDTO(
            title: title,
            fileName: fileName,
            genre: genre,
            duration: duration
            // artistName: artistName
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 0, userInfo: [NSLocalizedDescriptionKey: "Did not receive HTTPURLResponse"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to register AI song. Status: \(httpResponse.statusCode)",
                "responseBody": responseBody
            ])
        }
        
        let registeredSong = try JSONDecoder().decode(Song.self, from: data)
        return registeredSong
    }
    
    
    static func fetchPlaylist(with token: String, playlistID: String) async throws -> [PlayableTrackDTO] {
        var request = URLRequest(url: URL(string: Endpoints.Playlist.userPlaylistSongs(playlistID: playlistID))!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid response type"
            ])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch playlist. Status: \(httpResponse.statusCode)",
                "responseBody": responseBody
            ])
        }
        
        do {
            let playlist = try JSONDecoder().decode([PlayableTrackDTO].self, from: data)
            print("Successfully decoded playlist with \(playlist.count) tracks")
            return playlist
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            throw NSError(domain: "Decoding Error", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode playlist data: \(decodingError.localizedDescription)"
            ])
        } catch {
            print("Unexpected error: \(error)")
            throw error
        }
    }
    
    static func fetchRecommendPlaylists() async throws -> [PlaylistSummaryDTO] {
        var request = URLRequest(url: URL(string: Endpoints.Playlist.recommendPlaylists)!)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid Response", code: httpResponse.statusCode, userInfo: nil)
        }
        
        let recommendPlaylists = try JSONDecoder().decode([PlaylistSummaryDTO].self, from: data)
        return recommendPlaylists
    }
    
    static func fetchRecommendPlaylistSongs(with playlistID: String) async throws -> [PlayableTrackDTO] {
        var request = URLRequest(url: URL(string: Endpoints.Playlist.recommendPlaylistsSongs(playlistID: playlistID))!)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        
        do {
            let playlistSongs = try JSONDecoder().decode([PlayableTrackDTO].self, from: data)
            return playlistSongs
        } catch let decodingError as DecodingError {
            throw decodingError
        } catch {
            throw error
        }
    }
}
