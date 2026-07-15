//
//  LalalAIService.swift
//  BeamApp
//
//  Created by freed on 9/10/24.
//

import Foundation
import AVFoundation

// MARK: - LALAL.AI Errors
enum LalalAIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case taskCancelled
    case timeout
    case unknownTaskState(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .taskCancelled:
            return "Task was cancelled"
        case .timeout:
            return "Task timed out"
        case .unknownTaskState(let state):
            return "Unknown task state: \(state)"
        }
    }
}

// MARK: - AnyCodable for flexible JSON parsing
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let uint = try? container.decode(UInt.self) {
            self.value = uint
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let uint as UInt:
            try container.encode(uint)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(self.value, context)
        }
    }
}

// MARK: - LALAL.AI API Models
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
    let result: [String: AnyCodable]
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
    let task: LalalAITaskInfo?
    let archive: LalalAIArchiveResult?
    let error: String?
}

struct LalalAIArchiveResult: Codable {
    let duration: Double?
    let stem: String?
    let stem_track: String?
    let stem_track_size: Int?
    let back_track: String?
    let back_track_size: Int?
}

struct LalalAISplitResult: Codable {
    let duration: Double
    let stem: String
    let stem_track: String?
    let stem_track_size: Int?
    let back_track: String
    let back_track_size: Int
}

struct LalalAITaskInfo: Codable {
    let state: String
    let error: String?
    let progress: Int?
}

// MARK: - LALAL.AI Client
public class LalalAIClient {
    private let baseURL = "https://www.lalal.ai"
    private let apiKey: String
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - File Upload
    func uploadFile(audioData: Data, filename: String) async throws -> LalalAIUploadResponse {
        guard let url = URL(string: "\(baseURL)/api/upload/") else {
            throw LalalAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("attachment; filename=\(filename)", forHTTPHeaderField: "Content-Disposition")
        request.httpBody = audioData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LalalAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LalalAIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let uploadResponse = try JSONDecoder().decode(LalalAIUploadResponse.self, from: data)
        
        guard uploadResponse.status == "success" else {
            throw LalalAIError.serverError(uploadResponse.error ?? "Upload failed")
        }
        
        return uploadResponse
    }
    
    // MARK: - Voice Change
    func changeVoice(fileId: String, voice: String, accentEnhance: Float = 1.0, pitchShifting: Bool = true, dereverbEnabled: Bool = false) async throws -> LalalAIVoiceChangeResponse {
        guard let url = URL(string: "\(baseURL)/api/change_voice/") else {
            throw LalalAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "id": fileId,
            "voice": voice,
            "accent_enhance": String(accentEnhance),
            "pitch_shifting": String(pitchShifting),
            "dereverb_enabled": String(dereverbEnabled)
        ]
        
        let formData = parameters.map { key, value in
            "\(key)=\(value)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LalalAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LalalAIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        let voiceChangeResponse = try JSONDecoder().decode(LalalAIVoiceChangeResponse.self, from: data)
        
        guard voiceChangeResponse.status == "success" else {
            throw LalalAIError.serverError(voiceChangeResponse.error ?? "Voice change failed")
        }
        
        return voiceChangeResponse
    }
    
    // MARK: - Check Task Status
    func checkTaskStatus(fileId: String) async throws -> LalalAIFileResult {
        guard let url = URL(string: "\(baseURL)/api/check/") else {
            throw LalalAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = "id=\(fileId)".data(using: .utf8)
        request.httpBody = formData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LalalAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LalalAIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        // 응답 데이터 Debugging
        print("🔍 LALAL.AI check response:")
        print("   Response size: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            print("   Response body: \(responseString)")
        }
        
        // JSON 응답 구조 OK
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📋 JSON structure:")
            print("   Keys: \(Array(json.keys))")
            if let result = json["result"] as? [String: Any] {
                print("   Result keys: \(Array(result.keys))")
                if let fileResult = result[fileId] as? [String: Any] {
                    print("   File result keys: \(Array(fileResult.keys))")
                }
            }
        }
        
        let checkResponse = try JSONDecoder().decode(LalalAICheckResponse.self, from: data)
        
        guard checkResponse.status == "success" else {
            throw LalalAIError.serverError(checkResponse.error ?? "Check failed")
        }
        
        // fileId에 해당하는 결과를 찾기
        guard let fileResultAny = checkResponse.result[fileId] else {
            throw LalalAIError.serverError("File result not found")
        }
        
        // AnyCodable을 JSON으로 변환하여 파싱
        let fileResultData = try JSONSerialization.data(withJSONObject: fileResultAny.value)
        let fileResult = try JSONDecoder().decode(LalalAIFileResult.self, from: fileResultData)
        
        return fileResult
    }
    
    // MARK: - Download Audio File
    func downloadAudioFile(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw LalalAIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LalalAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LalalAIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    // MARK: - Check Credits
    func checkCredits() async throws -> (total: Double, used: Double, remaining: Double) {
        guard let url = URL(string: "\(baseURL)/billing/get-limits/?key=\(apiKey)") else {
            throw LalalAIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LalalAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LalalAIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        // 응답 파싱
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let status = json["status"] as? String, status == "success" {
                let total = json["process_duration_limit"] as? Double ?? 0.0
                let used = json["process_duration_used"] as? Double ?? 0.0
                let remaining = json["process_duration_left"] as? Double ?? 0.0
                
                return (total: total, used: used, remaining: remaining)
            } else {
                let error = json["error"] as? String ?? "Unknown error"
                throw LalalAIError.serverError(error)
            }
        } else {
            throw LalalAIError.serverError("Invalid response format")
        }
    }
    
    // MARK: - Wait for Task Completion
    func waitForTaskCompletion(fileId: String, maxWaitTime: TimeInterval = 300) async throws -> LalalAIFileResult {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            let fileResult = try await checkTaskStatus(fileId: fileId)
            
            if let task = fileResult.task {
                switch task.state {
                case "success":
                    return fileResult
                case "error":
                    throw LalalAIError.serverError(task.error ?? "Task failed")
                case "cancelled":
                    throw LalalAIError.taskCancelled
                case "progress":
                    // 진행 중이면 잠시 대기
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기
                    continue
                default:
                    throw LalalAIError.unknownTaskState(task.state)
                }
            } else {
                // task 정보가 없으면 바로 반환
                return fileResult
            }
        }
        
        throw LalalAIError.timeout
    }
} 