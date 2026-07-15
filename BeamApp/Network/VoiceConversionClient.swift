import Foundation
import ComposableArchitecture

// Voice conversion errors
enum VoiceConversionError: LocalizedError {
    case serverError(String)
    case invalidAudioData
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .invalidAudioData:
            return "Invalid audio data received"
        case .timeout:
            return "Voice conversion timed out"
        }
    }
}

// Voice conversion client
struct VoiceConversionClient {
    var getAvailableVoices: () async throws -> [VoiceInfo]
    var convertVoice: (Data, String, String, String?) async throws -> Data // Added voiceType parameter
}

extension VoiceConversionClient {
    static let live = Self(
        getAvailableVoices: {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            // Parse the new server response format
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let voicesArray = json["voices"] as? [[String: Any]] {
                    // New format: returned as a voices array
                    return voicesArray.compactMap { voiceDict in
                        guard let voiceId = voiceDict["voiceId"] as? String,
                              let name = voiceDict["name"] as? String,
                              let category = voiceDict["category"] as? String else {
                            return nil
                        }
                        
                        let description = voiceDict["description"] as? String
                        let previewUrl = voiceDict["preview_url"] as? String
                        let language = voiceDict["language"] as? [String]
                        
                        let voiceType = voiceDict["voiceType"] as? String ?? {
                            if category.contains("K-Pop") || category.contains("Western Pop") {
                                return "singer"
                            } else if category == "Default" {
                                return "default"
                            } else {
                                return "custom"
                            }
                        }()
                        
                        return VoiceInfo(
                            id: voiceId,
                            name: name,
                            category: category,
                            description: description,
                            previewUrl: previewUrl,
                            language: language,
                            voiceType: voiceType
                        )
                    }
                } else if let availableVoicesArray = json["available_voices"] as? [String] {
                    // Existing SeedVC API format (backward compatibility)
                    return availableVoicesArray.map { voiceId in
                        VoiceInfo(
                            id: voiceId,
                            name: voiceId.replacingOccurrences(of: "-", with: " ").capitalized,
                            category: "Default",
                            description: "Voice ID: \(voiceId)",
                            previewUrl: nil,
                            language: ["en"],
                            voiceType: "default"
                        )
                    }
                } else {
                    throw URLError(.cannotParseResponse)
                }
            } else {
                throw URLError(.cannotParseResponse)
            }
        },
        
        convertVoice: { audioData, voiceId, outputFormat, voiceType in
            let maxRetries = 3
            var lastError: Error?
            
            for attempt in 1...maxRetries {
                do {
                    return try await performVoiceConversion(audioData: audioData, voiceId: voiceId, outputFormat: outputFormat, voiceType: voiceType)
                } catch let error as VoiceConversionError {
                    if case .serverError(let message) = error, message.contains("timed out") {
                        lastError = error
                        if attempt < maxRetries {
                            // Wait before retry (exponential backoff)
                            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                            continue
                        }
                    }
                    throw error
                } catch {
                    lastError = error
                    if attempt < maxRetries {
                        // Wait before retry (exponential backoff)
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                        continue
                    }
                    throw error
                }
            }
            
            throw lastError ?? VoiceConversionError.timeout
        }
    )
    
    // Helper function to perform the actual voice conversion request
    private static func performVoiceConversion(audioData: Data, voiceId: String, outputFormat: String, voiceType: String?) async throws -> Data {
        guard let url = URL(string: Endpoints.VoiceConversion.convert) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1800 // 30 minutes timeout (matching Vapor server)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add source audio file (Vapor server API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source_audio\"; filename=\"audio.mp3\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add voice ID for target audio generation (Vapor server API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voiceId\"\r\n\r\n".data(using: .utf8)!)
        body.append(voiceId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add voiceType parameter for singer voices
        if let voiceType = voiceType, voiceType == "singer" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voiceType\"\r\n\r\n".data(using: .utf8)!)
            body.append(voiceType.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add language parameter (Vapor server API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add preserve_melody parameter (Vapor server API)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"preserve_melody\"\r\n\r\n".data(using: .utf8)!)
        body.append("true".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // URLSession configuration for long timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1800 // 30 minutes
        config.timeoutIntervalForResource = 3600 // 60 minutes
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Vapor server response handling: success = audio data, failure = JSON error
        if let responseString = String(data: data, encoding: .utf8),
           responseString.hasPrefix("{") {
            // JSON response indicates error
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let errorMessage = jsonResponse["error"] as? String ?? jsonResponse["reason"] as? String ?? "Unknown error"
                throw VoiceConversionError.serverError(errorMessage)
            } else {
                throw VoiceConversionError.serverError("Invalid JSON response")
            }
        }
        
        // If not JSON, treat as audio data
        guard data.count > 1000 else {
            throw VoiceConversionError.invalidAudioData
        }
        
        return data
    }
    
    static let mock = Self(
        getAvailableVoices: {
            return VoiceInfo.beamSVCFallbackVoices
        },
        convertVoice: { audioData, voiceId, outputFormat, voiceType in
            // Return mock audio data
            return audioData
        }
    )
}

// For TCA dependency
extension VoiceConversionClient: DependencyKey {
    static var liveValue = VoiceConversionClient.live
    static var testValue = VoiceConversionClient.mock
}

extension DependencyValues {
    var voiceConversionClient: VoiceConversionClient {
        get { self[VoiceConversionClient.self] }
        set { self[VoiceConversionClient.self] = newValue }
    }
} 
