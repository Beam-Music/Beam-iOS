//
//  AIPreferenceClient.swift
//  BeamApp
//
//  Created by anonymous on 4/9/25.
//

import Foundation
import ComposableArchitecture

// Models for API requests/responses
struct AIPreferenceRequest: Codable {
    let userId: UUID
    let enableAIMusic: Bool
}

struct AIPreferenceResponse: Codable {
    let id: UUID?
    let userId: UUID
    let enableAIMusic: Bool
}

struct AIPreferenceClient {
    var updateAIPreference: (UUID, Bool) async throws -> Bool
    var getAIPreference: (UUID) async throws -> Bool
}

extension AIPreferenceClient {
    static let live = Self(
        updateAIPreference: { userId, enabled in
            let url = URL(string: Endpoints.AIPreference.updatePreference(userId: userId))!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let preference = AIPreferenceRequest(userId: userId, enableAIMusic: enabled)
            request.httpBody = try JSONEncoder().encode(preference)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let decodedResponse = try JSONDecoder().decode(AIPreferenceResponse.self, from: data)
            return decodedResponse.enableAIMusic
        },
        
        getAIPreference: { userId in
            let url = URL(string: Endpoints.AIPreference.getPreference(userId: userId))!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let preference = try JSONDecoder().decode(AIPreferenceResponse.self, from: data)
            return preference.enableAIMusic
        }
    )
}

extension AIPreferenceClient: DependencyKey {
    static var liveValue = AIPreferenceClient.live
    
    static var testValue = Self(
        updateAIPreference: { _, enabled in
            return enabled
        },
        getAIPreference: { _ in
            return false
        }
    )
}

extension DependencyValues {
    var aiPreferenceClient: AIPreferenceClient {
        get { self[AIPreferenceClient.self] }
        set { self[AIPreferenceClient.self] = newValue }
    }
}
