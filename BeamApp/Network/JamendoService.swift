//
//  JamendoService.swift
//  BeamApp
//

import Foundation

final class JamendoService {
    static let shared = JamendoService()

    private let baseURL = Endpoints.Jamendo.baseURL
    private let clientId = Endpoints.Jamendo.clientId

    private init() {}

    // MARK: - Track Search

    func searchTracks(query: String, limit: Int = 20) async throws -> [JamendoTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "include", value: "musicinfo"),
            URLQueryItem(name: "audioformat", value: "mp3")
        ]
        return try await fetchTracks(from: components)
    }

    // MARK: - Popular Tracks

    func getPopularTracks(limit: Int = 10) async throws -> [JamendoTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "order", value: "popularity_week"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "audioformat", value: "mp3")
        ]
        return try await fetchTracks(from: components)
    }

    // MARK: - Artist Search

    func searchArtists(name: String, limit: Int = 10) async throws -> [JamendoArtist] {
        guard var components = URLComponents(string: "\(baseURL)/artists/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "namesearch", value: name),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw JamendoError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.serverError
        }

        let decoded = try JSONDecoder().decode(JamendoResponse<JamendoArtist>.self, from: data)
        return decoded.results
    }

    // MARK: - Download Audio Data

    func downloadAudioData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw JamendoError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.downloadFailed
        }
        return data
    }

    // MARK: - Private Helpers

    private func fetchTracks(from components: URLComponents) async throws -> [JamendoTrack] {
        guard let url = components.url else {
            throw JamendoError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.serverError
        }

        let decoded = try JSONDecoder().decode(JamendoResponse<JamendoTrack>.self, from: data)
        return decoded.results
    }
}

enum JamendoError: Error, LocalizedError {
    case invalidURL
    case serverError
    case downloadFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .serverError:
            return "A server error occurred."
        case .downloadFailed:
            return "Failed to download audio."
        case .noResults:
            return "No search results."
        }
    }
}

final class AudiusService {
    static let shared = AudiusService()

    private let baseURL = "https://api.audius.co/v1"
    private let appName = "beamapp"

    private init() {}

    func searchTracks(query: String, limit: Int = 20) async throws -> [AudiusTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/search") else {
            throw AudiusError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "app_name", value: appName),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetch(AudiusResponse<[AudiusTrack]>.self, from: components).data
    }

    func getTrendingTracks(limit: Int = 10) async throws -> [AudiusTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/trending") else {
            throw AudiusError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "app_name", value: appName),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetch(AudiusResponse<[AudiusTrack]>.self, from: components).data
    }

    func searchUsers(query: String, limit: Int = 10) async throws -> [AudiusUser] {
        guard var components = URLComponents(string: "\(baseURL)/users/search") else {
            throw AudiusError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "app_name", value: appName),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetch(AudiusResponse<[AudiusUser]>.self, from: components).data
    }

    func getTrack(id: String) async throws -> AudiusTrack {
        guard var components = URLComponents(string: "\(baseURL)/tracks/\(id)") else {
            throw AudiusError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "app_name", value: appName)
        ]
        return try await fetch(AudiusResponse<AudiusTrack>.self, from: components).data
    }

    func streamURL(for trackID: String) -> String {
        "\(baseURL)/tracks/\(trackID)/stream?app_name=\(appName)"
    }

    private func fetch<T: Decodable>(_ type: T.Type, from components: URLComponents) async throws -> T {
        guard let url = components.url else {
            throw AudiusError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AudiusError.serverError
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AudiusError.decodingError(error)
        }
    }
}

struct AudiusResponse<T: Decodable>: Decodable {
    let data: T
}

struct AudiusTrack: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let genre: String?
    let duration: Double?
    let artwork: AudiusArtwork?
    let stream: AudiusStream?
    let user: AudiusUser

    func toMusicSearchResult() -> MusicSearchResult {
        MusicSearchResult(
            id: id,
            title: title,
            artist: user.name,
            artworkURL: artwork?.url480 ?? user.profilePicture?.url480 ?? user.profilePicture?.url150,
            isExplicit: false,
            playbackURL: AudiusService.shared.streamURL(for: id),
            genre: genre
        )
    }
}

struct AudiusUser: Decodable, Identifiable {
    let id: String
    let name: String
    let handle: String?
    let profilePicture: AudiusArtwork?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case handle
        case profilePicture = "profile_picture"
    }
}

struct AudiusStream: Decodable {
    let url: String
}

struct AudiusArtwork: Decodable {
    let url150: URL?
    let url480: URL?
    let url1000: URL?

    enum CodingKeys: String, CodingKey {
        case url150 = "150x150"
        case url480 = "480x480"
        case url1000 = "1000x1000"
    }
}

enum AudiusError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Audius URL."
        case .serverError:
            return "An Audius server error occurred."
        case .decodingError(let error):
            return "Failed to parse Audius response: \(error.localizedDescription)"
        }
    }
}
