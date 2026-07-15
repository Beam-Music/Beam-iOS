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

    static func updateUsername(userId: String, token: String, username: String) async throws {
        let url = URL(string: "\(Endpoints.baseURL)/api/users/\(userId)/profile")!
        let methods = ["PUT", "PATCH"]
        let body = try JSONSerialization.data(withJSONObject: ["username": username])

        for method in methods {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                if method == methods.last {
                    throw UserProfileError.network(error.localizedDescription)
                }
            }
        }

        throw UserProfileError.unknown
    }
}

enum UserProfileError: Error, Equatable, LocalizedError {
    case network(String)
    case decoding(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .decoding(let message):
            return message
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
