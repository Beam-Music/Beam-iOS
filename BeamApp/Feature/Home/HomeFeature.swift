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

    static func fetchListeningHistory(with token: String) async throws -> [ListeningHistoryItem] {
            var request = URLRequest(url: URL(string: "http://192.168.0.50:8080/listening-history/")!)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "Invalid Response", code: 400, userInfo: nil)
            }

            do {
                let history = try JSONDecoder().decode([ListeningHistoryItem].self, from: data)
                return history
            } catch let decodingError as DecodingError {
                print("Failed to decode JSON: \(decodingError)")
                throw decodingError
            } catch {
                print("Unexpected error: \(error)")
                throw error
            }
        }
}
