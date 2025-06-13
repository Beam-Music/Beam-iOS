//
//  UserProfileClient 2.swift
//  BeamApp
//
//  Created by anonymous on 6/10/25.
//

import Foundation

struct UserProfileClient {
    static func fetchProfile(userId: String, token: String) async throws -> UserProfile {
        let url = URL(string: "\(Endpoints.baseURL)/api/users/\(userId)/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch let error as DecodingError {
            throw UserProfileError.decoding(error.localizedDescription)
        } catch {
            throw UserProfileError.network(error.localizedDescription)
        }
    }
}

enum UserProfileError: Error, Equatable {
    case network(String)
    case decoding(String)
    case unknown
}
