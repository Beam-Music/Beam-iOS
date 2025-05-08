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
            print("📡 Fetching AI songs from server...")
            var request = URLRequest(url: URL(string: Endpoints.AISong.playable)!)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
            print("🟡 AI Songs Response Status: \(httpResponse.statusCode)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("📥 Response body: \(responseBody)")
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.serverError(httpResponse.statusCode, errorBody.reason)
                }
                throw APIError.serverError(httpResponse.statusCode, "Unknown error")
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let tracks = try decoder.decode([PlayableTrackDTO].self, from: data)
                print("✅ Successfully decoded \(tracks.count) AI tracks")
                
                // Ensure all tracks have proper playback information
                return tracks.map { track in
                    var modifiedTrack = track
                    if track.isAIGenerated {
                        // For AI tracks, use fileUrl
                        if modifiedTrack.fileUrl == nil {
                            modifiedTrack.fileUrl = "https://audio.jukehost.co.uk/gcP4CuiFEBSG8rTyRl0vwSWqRVP1XgTc"
                        }
                        modifiedTrack.playbackUrl = modifiedTrack.fileUrl
                        modifiedTrack.playbackStoreID = nil
                    } else {
                        // For non-AI tracks, ensure playbackStoreID is set
                        if modifiedTrack.playbackStoreID == nil {
                            modifiedTrack.playbackStoreID = "1672543889" // Default Apple Music ID
                        }
                        modifiedTrack.fileUrl = nil
                    }
                    return modifiedTrack
                }
            } catch {
                print("🔴 Failed to decode AI songs: \(error)")
                throw APIError.decodingError(error)
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