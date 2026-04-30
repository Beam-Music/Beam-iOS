import Foundation
import ComposableArchitecture

// API Client for AI Preferences
struct AIPreferenceClient {
    var getPreference: @Sendable (UUID) async throws -> AIPreference
    var updatePreference: @Sendable (UUID, Bool) async throws -> AIPreference
}

extension AIPreferenceClient {
    static let live = Self(
        getPreference: { userId in
            let url = URL(string: Endpoints.AIPreference.getPreference(userId: userId))!
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(AIPreference.self, from: data)
        },
        updatePreference: { userId, enableAIMusic in
            let url = URL(string: Endpoints.AIPreference.updatePreference(userId: userId))!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let preference = AIPreference(userId: userId, enableAIMusic: enableAIMusic)
            request.httpBody = try JSONEncoder().encode(preference)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(AIPreference.self, from: data)
        }
    )
    
    static let mock = Self(
        getPreference: { userId in
            // Return mock data for testing
            return AIPreference(userId: userId, enableAIMusic: false)
        },
        updatePreference: { userId, enableAIMusic in
            // Return mock data for testing
            return AIPreference(userId: userId, enableAIMusic: enableAIMusic)
        }
    )
}

// For TCA dependency
extension DependencyValues {
    var aiPreferenceClient: AIPreferenceClient {
        get { self[AIPreferenceClient.self] }
        set { self[AIPreferenceClient.self] = newValue }
    }
}

extension AIPreferenceClient: DependencyKey {
    static var liveValue = AIPreferenceClient.live
    static var previewValue = AIPreferenceClient.mock
    static var testValue = AIPreferenceClient.mock
}
