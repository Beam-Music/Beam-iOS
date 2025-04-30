//
//  APIClients.swift
//  BeamApp
//
//  Created by anonymous on 4/29/25.
//

import ComposableArchitecture
import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct APIClient {
    var getNextTrack: @Sendable (UUID, Bool) async throws -> PlayableTrackDTO
    var getPlayableAISongs: @Sendable (String) async throws -> [PlayableTrackDTO]
    
    static let shared = APIClient(
        getNextTrack: { currentTrackID, isAIMusicEnabled in
            var components = URLComponents(string: Endpoints.AISong.nextTrack)!
            components.queryItems = [
                URLQueryItem(name: "current_track_id", value: currentTrackID.uuidString),
                URLQueryItem(name: "is_ai_music_enabled", value: String(isAIMusicEnabled))
            ]
            
            guard let url = components.url else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(PlayableTrackDTO.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        },
        getPlayableAISongs: { token in
            let urlString = Endpoints.AISong.playable
            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard (200..<300).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.serverError(httpResponse.statusCode, errorMessage)
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                var tracks = try decoder.decode([PlayableTrackDTO].self, from: data)
                
                // Create new tracks with isAIGenerated set to true
                tracks = tracks.map { track in
                    PlayableTrackDTO(
                        id: track.id,
                        title: track.title,
                        artistName: track.artistName,
                        playbackUrl: track.playbackUrl,
                        playbackStoreID: track.playbackStoreID,
                        isAIGenerated: true,
                        duration: track.duration,
                        fileUrl: track.fileUrl
                    )
                }
                
                return tracks
            } catch let error as APIError {
                throw error
            } catch {
                throw APIError.networkError(error)
            }
        }
    )
}

extension APIClient: DependencyKey {
    static let liveValue: APIClient = shared
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

private struct APIClientKey: DependencyKey {
    static let liveValue: APIClient = APIClient.liveValue
}

