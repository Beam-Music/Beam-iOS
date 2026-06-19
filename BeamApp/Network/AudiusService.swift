//
//  AudiusService.swift
//  BeamApp
//

import Foundation

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
            playbackURL: stream?.url
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
            return "잘못된 Audius URL입니다."
        case .serverError:
            return "Audius 서버 오류가 발생했습니다."
        case .decodingError(let error):
            return "Audius 응답 해석 실패: \(error.localizedDescription)"
        }
    }
}
