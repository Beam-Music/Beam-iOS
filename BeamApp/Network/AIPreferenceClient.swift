import Foundation
import ComposableArchitecture

enum AIPreferenceError: Error, Equatable {
    case invalidResponse
    case serverError(String)
    case networkError(String)
}

// Define the dependency keys
extension DependencyValues {
    var getAIPreference: (UUID) async throws -> AIPreference {
        get { self[GetAIPreferenceKey.self] }
        set { self[GetAIPreferenceKey.self] = newValue }
    }
    
    var updateAIPreference: (UUID, Bool) async throws -> AIPreference {
        get { self[UpdateAIPreferenceKey.self] }
        set { self[UpdateAIPreferenceKey.self] = newValue }
    }
    
    var createAIPreference: (UUID, Bool) async throws -> AIPreference {
        get { self[CreateAIPreferenceKey.self] }
        set { self[CreateAIPreferenceKey.self] = newValue }
    }
}

// Implement the dependency keys
private struct GetAIPreferenceKey: DependencyKey {
    static var liveValue: (UUID) async throws -> AIPreference = { userId in
        let urlString = Endpoints.AIPreference.getPreference(userId: userId)
        guard let url = URL(string: urlString) else {
            throw AIPreferenceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIPreferenceError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                // If preference not found, create a default one
                return try await CreateAIPreferenceKey.liveValue(userId, false)
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIPreferenceError.serverError("Server returned status code \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AIPreference.self, from: data)
        } catch let error as AIPreferenceError {
            throw error
        } catch {
            throw AIPreferenceError.networkError(error.localizedDescription)
        }
    }
}

private struct UpdateAIPreferenceKey: DependencyKey {
    static var liveValue: (UUID, Bool) async throws -> AIPreference = { userId, enableAIMusic in
        let urlString = Endpoints.AIPreference.updatePreference(userId: userId)
        guard let url = URL(string: urlString) else {
            throw AIPreferenceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let preference = AIPreference(userId: userId, enableAIMusic: enableAIMusic)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(preference)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIPreferenceError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                // If preference not found, create a new one
                return try await CreateAIPreferenceKey.liveValue(userId, enableAIMusic)
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIPreferenceError.serverError("Server returned status code \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AIPreference.self, from: data)
        } catch let error as AIPreferenceError {
            throw error
        } catch {
            throw AIPreferenceError.networkError(error.localizedDescription)
        }
    }
}

private struct CreateAIPreferenceKey: DependencyKey {
    static var liveValue: (UUID, Bool) async throws -> AIPreference = { userId, enableAIMusic in
        let urlString = Endpoints.AIPreference.createPreference
        guard let url = URL(string: urlString) else {
            throw AIPreferenceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let preference = AIPreference(userId: userId, enableAIMusic: enableAIMusic)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(preference)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIPreferenceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 201 else {
                throw AIPreferenceError.serverError("Server returned status code \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AIPreference.self, from: data)
        } catch let error as AIPreferenceError {
            throw error
        } catch {
            throw AIPreferenceError.networkError(error.localizedDescription)
        }
    }
}
