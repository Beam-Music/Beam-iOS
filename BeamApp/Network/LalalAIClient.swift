import Foundation
import ComposableArchitecture

// MARK: - LalalAI API Models
struct LalalAIUploadResponse: Codable {
    let status: String
    let id: String?
    let size: Int?
    let duration: Double?
    let expires: Int?
    let error: String?
}

struct LalalAIVoiceChangeResponse: Codable {
    let status: String
    let id: String?
    let task_id: String?
    let error: String?
}

struct LalalAICheckResponse: Codable {
    let status: String
    let result: [String: LalalAIFileResult]?
    let error: String?
}

struct LalalAIFileResult: Codable {
    let status: String
    let name: String?
    let size: Int?
    let duration: Double?
    let splitter: String?
    let stem: String?
    let split: LalalAISplitResult?
    let task: LalalAITaskResult?
    let error: String?
}

struct LalalAISplitResult: Codable {
    let duration: Double
    let stem: String
    let stem_track: String
    let stem_track_size: Int
    let back_track: String
    let back_track_size: Int
}

struct LalalAITaskResult: Codable {
    let state: String
    let error: String?
    let progress: Int?
}

// MARK: - LalalAI Client
struct LalalAIClient {
    var uploadFile: (Data, String) async throws -> LalalAIUploadResponse
    var changeVoice: (String, String) async throws -> LalalAIVoiceChangeResponse
    var checkResult: (String) async throws -> LalalAICheckResponse
}

extension LalalAIClient {
    static let live = Self(
        uploadFile: { audioData, filename in
            let apiKey = "50895a975bdd4a14"
            let url = URL(string: "https://www.lalal.ai/api/upload/")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("attachment; filename=\(filename)", forHTTPHeaderField: "Content-Disposition")
            request.setValue("audio/mpeg", forHTTPHeaderField: "Content-Type")
            request.httpBody = audioData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let uploadResponse = try JSONDecoder().decode(LalalAIUploadResponse.self, from: data)
            
            if uploadResponse.status == "error" {
                throw LalalAIError.uploadFailed(uploadResponse.error ?? "Unknown upload error")
            }
            
            return uploadResponse
        },
        
        changeVoice: { fileId, voice in
            let apiKey = "50895a975bdd4a14"
            let url = URL(string: "https://www.lalal.ai/api/change_voice/")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = "id=\(fileId)&voice=\(voice)&accent_enhance=true&pitch_shifting=true&dereverb_enabled=false"
            request.httpBody = body.data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let voiceChangeResponse = try JSONDecoder().decode(LalalAIVoiceChangeResponse.self, from: data)
            
            if voiceChangeResponse.status == "error" {
                throw LalalAIError.voiceChangeFailed(voiceChangeResponse.error ?? "Unknown voice change error")
            }
            
            return voiceChangeResponse
        },
        
        checkResult: { fileId in
            let apiKey = "50895a975bdd4a14"
            let url = URL(string: "https://www.lalal.ai/api/check/")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = "id=\(fileId)"
            request.httpBody = body.data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let checkResponse = try JSONDecoder().decode(LalalAICheckResponse.self, from: data)
            
            if checkResponse.status == "error" {
                throw LalalAIError.checkFailed(checkResponse.error ?? "Unknown check error")
            }
            
            return checkResponse
        }
    )
    
    static let mock = Self(
        uploadFile: { _, _ in
            return LalalAIUploadResponse(
                status: "success",
                id: "mock-file-id",
                size: 1000000,
                duration: 60.0,
                expires: Int(Date().timeIntervalSince1970) + 86400,
                error: nil
            )
        },
        changeVoice: { _, _ in
            return LalalAIVoiceChangeResponse(
                status: "success",
                id: "mock-file-id",
                task_id: "mock-task-id",
                error: nil
            )
        },
        checkResult: { _ in
            return LalalAICheckResponse(
                status: "success",
                result: [
                    "mock-file-id": LalalAIFileResult(
                        status: "success",
                        name: "converted.mp3",
                        size: 1000000,
                        duration: 60.0,
                        splitter: "phoenix",
                        stem: "vocals",
                        split: LalalAISplitResult(
                            duration: 60.0,
                            stem: "vocals",
                            stem_track: "https://example.com/stem.mp3",
                            stem_track_size: 500000,
                            back_track: "https://example.com/back.mp3",
                            back_track_size: 500000
                        ),
                        task: LalalAITaskResult(
                            state: "success",
                            error: nil,
                            progress: 100
                        ),
                        error: nil
                    )
                ],
                error: nil
            )
        }
    )
}

// MARK: - LalalAI Errors
enum LalalAIError: LocalizedError {
    case uploadFailed(String)
    case voiceChangeFailed(String)
    case checkFailed(String)
    case processingNotComplete
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .voiceChangeFailed(let message):
            return "Voice change failed: \(message)"
        case .checkFailed(let message):
            return "Check failed: \(message)"
        case .processingNotComplete:
            return "Processing not complete yet"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

// MARK: - TCA Dependency
extension LalalAIClient: DependencyKey {
    static var liveValue = LalalAIClient.live
    static var testValue = LalalAIClient.mock
}

extension DependencyValues {
    var lalalAIClient: LalalAIClient {
        get { self[LalalAIClient.self] }
        set { self[LalalAIClient.self] = newValue }
    }
} 