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
            print("🔴 No token found in storage")
            throw NSError(domain: "No Token Found", code: 401, userInfo: nil)
        }
        print("🟢 Token found: \(token.prefix(10))...")
        return token
    }
    
    static func fetchUserPlaylists(with token: String) async throws -> [PlaylistSummaryDTO] {
        print("🔵 Fetching user playlists with token: \(token.prefix(10))...")
        var request = URLRequest(url: URL(string: Endpoints.Playlist.userPlaylist)!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 Sending request to: \(request.url?.absoluteString ?? "unknown")")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 Invalid response type")
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        
        print("🟡 Response status code: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("📥 Response body: \(responseBody)")
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("🔴 Error response: \(responseBody)")
            throw NSError(domain: "Invalid Response", code: httpResponse.statusCode, userInfo: nil)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let userPlaylists = try decoder.decode([PlaylistSummaryDTO].self, from: data)
            print("🟢 Successfully fetched \(userPlaylists.count) playlists")
            print("📋 Playlists: \(userPlaylists.map { "'\($0.name)'" }.joined(separator: ", "))")
            return userPlaylists
        } catch {
            print("🔴 Failed to decode playlists: \(error)")
            throw error
        }
    }
    
    static func fetchPlayableAISongs(token: String) async throws -> [PlayableTrackDTO] {
        print("🌐 Fetching AI songs...")
        print("🔑 Using token: \(token.prefix(10))...")
        
        do {
            let tracks = try await APIClient.shared.getPlayableAISongs(token)
            print("✅ Successfully fetched \(tracks.count) AI tracks")
            
            // Validate and log track data
            tracks.forEach { track in
                print("🎵 Track: \(track.title)")
                print("   AI Generated: \(track.isAIGenerated)")
                print("   File URL: \(track.fileUrl ?? "none")")
                print("   Playback URL: \(track.playbackUrl ?? "none")")
                print("   Store ID: \(track.playbackStoreID ?? "none")")
            }
            
            // Filter and ensure proper URLs are set
            return tracks.map { track in
                var modifiedTrack = track
                if track.isAIGenerated && track.fileUrl == nil {
                    // If AI track is missing fileUrl, try to construct it
                    modifiedTrack.fileUrl = "https://audio.jukehost.co.uk/gcP4CuiFEBSG8rTyRl0vwSWqRVP1XgTc"
                }
                return modifiedTrack
            }
        } catch {
            print("❌ Failed to fetch AI songs: \(error)")
            throw error
        }
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
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let playlist = try decoder.decode([PlayableTrackDTO].self, from: data)
            print("Successfully decoded playlist with \(playlist.count) tracks")
            
            // Map the tracks to include proper playback information
            return playlist.map { track in
                PlayableTrackDTO(
                    id: track.id,
                    title: track.title,
                    artistName: track.artistName,
                    playbackUrl: track.playbackUrl,
                    playbackStoreID: track.isAIGenerated ? nil : track.playbackStoreID, // Use storeID for non-AI tracks
                    isAIGenerated: track.isAIGenerated,
                    duration: track.duration,
                    fileUrl: track.isAIGenerated ? track.fileUrl : nil // Use fileUrl for AI tracks
                )
            }
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
        // Get token for authentication
        guard let token = await TokenStorage.shared.fetchToken() else {
            print("🔴 No token found in storage")
            throw NSError(domain: "No Token Found", code: 401, userInfo: nil)
        }
        print("🔑 Using token for recommend playlists: \(token.prefix(10))...")
        
        var request = URLRequest(url: URL(string: Endpoints.Playlist.recommendPlaylists)!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📡 Sending request to: \(request.url?.absoluteString ?? "unknown")")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔴 Invalid response type")
            throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
        }
        
        print("🟡 Response status code: \(httpResponse.statusCode)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("📥 Response body: \(responseBody)")
        }
        
        // Handle 404 by returning empty array instead of throwing
        if httpResponse.statusCode == 404 {
            print("ℹ️ No recommended playlists found")
            return []
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("🔴 Error response: \(responseBody)")
            throw NSError(domain: "Server Error", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: responseBody
            ])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let recommendPlaylists = try decoder.decode([RecommendPlaylist].self, from: data)
            print("✅ Successfully decoded \(recommendPlaylists.count) recommended playlists")
            print("📋 Recommended playlists: \(recommendPlaylists.map { "'\($0.name)'" }.joined(separator: ", "))")
            
            // Convert RecommendPlaylist to PlaylistSummaryDTO
            return recommendPlaylists.map { playlist in
                PlaylistSummaryDTO(
                    id: playlist.id,
                    name: playlist.name,
                    user: playlist.user.map { user in
                        PlaylistSummaryDTO.User(
                            id: user.id,
                            username: user.username
                        )
                    }
                )
            }
        } catch {
            print("🔴 Failed to decode playlists: \(error)")
            throw APIError.decodingError(error)
        }
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
