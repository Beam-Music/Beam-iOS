import ComposableArchitecture
import Foundation

struct APIClient {
    var getNextTrack: @Sendable (UUID, Bool) async throws -> PlayableTrackDTO
}

extension APIClient: DependencyKey {
    static let liveValue: APIClient = APIClient(
        getNextTrack: { currentTrackID, isAIMusicEnabled in
            var components = URLComponents(string: Endpoints.AISong.nextTrack)!
            components.queryItems = [
                URLQueryItem(name: "current_track_id", value: currentTrackID.uuidString),
                URLQueryItem(name: "is_ai_music_enabled", value: String(isAIMusicEnabled))
            ]
            
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.cannotParseResponse)
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(PlayableTrackDTO.self, from: data)
        }
    )
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