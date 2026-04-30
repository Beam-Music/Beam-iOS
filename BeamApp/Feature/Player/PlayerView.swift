//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import AVFoundation
import MusicKit

private let voiceConversionService = VoiceConversionService()

class LalalAIClient {
    private let baseURL = "https://www.lalal.ai"
    private let apiKey: String
    private let session = URLSession.shared
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
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
        
        let checkResponse = try JSONDecoder().decode(LalalAICheckResponse.self, from: data)
        
        guard checkResponse.status == "success" else {
            throw LalalAIError.serverError(checkResponse.error ?? "Check failed")
        }
        
        guard let fileResultAny = checkResponse.result[fileId] else {
            throw LalalAIError.serverError("File result not found")
        }
        
        let fileResultData = try JSONSerialization.data(withJSONObject: fileResultAny.value)
        let fileResult = try JSONDecoder().decode(LalalAIFileResult.self, from: fileResultData)
        
        return fileResult
    }
    
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
                    try await Task.sleep(nanoseconds: 2_000_000_000) 
                    continue
                default:
                    throw LalalAIError.unknownTaskState(task.state)
                }
            } else {
                return fileResult
            }
        }
        
        throw LalalAIError.timeout
    }
}

class VoiceConversionService {
    
    func performLalalAIVoiceChange(
        audioData: Data,
        voiceId: String
    ) async throws -> Data {
        let client = LalalAIClient(apiKey: APIKeys.lalalAI)

        do {
            let credits = try await client.checkCredits()
            
            let estimatedDuration = Double(audioData.count) / 16000.0
            let requiredMinutes = estimatedDuration / 60.0
            
            if credits.remaining < requiredMinutes {
                let maxAllowedDuration = credits.remaining * 60.0
                let maxAllowedSeconds = min(maxAllowedDuration, 30.0)
                
                let trimmedAudioData = try await trimAudioToDuration(audioData, duration: maxAllowedSeconds)
                
                return try await performLalalAIVoiceChangeWithTrimmedAudio(
                    audioData: trimmedAudioData,
                    voiceId: voiceId
                )
            }
            let filename = "audio_\(Int(Date().timeIntervalSince1970)).mp3"
            let uploadResponse = try await client.uploadFile(audioData: audioData, filename: filename)
            
            guard let fileId = uploadResponse.id else {
                throw VoiceConversionError.serverError("Failed to get file ID from upload")
            }
            
            // 가수 음성 ID를 LALAL.AI voice pack으로 매핑
            let lalalAIVoice = getLalalAIVoiceId(singerVoiceId: voiceId)
            
            let voiceChangeResponse = try await client.changeVoice(
                fileId: fileId,
                voice: lalalAIVoice,
                accentEnhance: 1.0,      // 액센트 강화 활성화
                pitchShifting: true,     // 피치 시프팅 활성화
                dereverbEnabled: false   // 디리버브 비활성화
            )
            
            guard let taskId = voiceChangeResponse.task_id else {
                throw VoiceConversionError.serverError("Failed to get task ID from voice change")
            }
            
            let fileResult = try await client.waitForTaskCompletion(fileId: fileId, maxWaitTime: 300)
            
            let downloadUrl: String
            let fileSize: Int
            
            if let archive = fileResult.archive, let stemTrack = archive.stem_track, !stemTrack.isEmpty {
                downloadUrl = stemTrack
                fileSize = archive.stem_track_size ?? 0
            } else if let split = fileResult.split, !split.back_track.isEmpty {
                downloadUrl = split.back_track
                fileSize = split.back_track_size
            } else {
                throw VoiceConversionError.serverError("No download URL available in result")
            }
            
            // 변환된 음성 다운로드
            let convertedAudioData = try await client.downloadAudioFile(from: downloadUrl)
            
            return convertedAudioData
            
        } catch {
            print("❌ LALAL.AI Voice Change error: \(error)")
            throw error
        }
    }
    
    // 크레딧이 부족할 때 자른 오디오로 음성 변환 (재귀 방지)
    func performLalalAIVoiceChangeWithTrimmedAudio(
        audioData: Data,
        voiceId: String
    ) async throws -> Data {
        let client = LalalAIClient(apiKey: APIKeys.lalalAI)

        do {
            let filename = "trimmed_audio_\(Int(Date().timeIntervalSince1970)).mp3"
            let uploadResponse = try await client.uploadFile(audioData: audioData, filename: filename)
            
            guard let fileId = uploadResponse.id else {
                throw VoiceConversionError.serverError("Failed to get file ID from upload")
            }
            // 가수 음성 ID를 LALAL.AI voice pack으로 매핑
            let lalalAIVoice = getLalalAIVoiceId(singerVoiceId: voiceId)
            
            let voiceChangeResponse = try await client.changeVoice(
                fileId: fileId,
                voice: lalalAIVoice,
                accentEnhance: 1.0,      // 액센트 강화 활성화
                pitchShifting: true,     // 피치 시프팅 활성화
                dereverbEnabled: false   // 디리버브 비활성화
            )
            
            guard let taskId = voiceChangeResponse.task_id else {
                throw VoiceConversionError.serverError("Failed to get task ID from voice change")
            }
            
            let fileResult = try await client.waitForTaskCompletion(fileId: fileId, maxWaitTime: 300)
            
            // archive 또는 split 결과에서 다운로드 URL 찾기
            let downloadUrl: String
            let fileSize: Int
            
            if let archive = fileResult.archive, let stemTrack = archive.stem_track, !stemTrack.isEmpty {
                downloadUrl = stemTrack
                fileSize = archive.stem_track_size ?? 0
            } else if let split = fileResult.split, !split.back_track.isEmpty {
                downloadUrl = split.back_track
                fileSize = split.back_track_size
            } else {
                throw VoiceConversionError.serverError("No download URL available in result")
            }
            
            let convertedAudioData = try await client.downloadAudioFile(from: downloadUrl)
            
            return convertedAudioData
            
        } catch {
            print("❌ LALAL.AI Voice Change error for trimmed audio: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Functions
    
    private func getLalalAIVoiceId(singerVoiceId: String) -> String {
        print("🎤 Getting LALAL.AI voice ID for singer: \(singerVoiceId)")
        
        // LALAL.AI에서 제공하는 Legal Voice Packs 매핑
        let singerVoiceMapping: [String: String] = [
            // Western Pop/Rap Artists 
            "drake_singer": "ALEX_KAYE",           // Drake -> ALEX_KAYE (남성)
            "bad_bunny_singer": "ALEX_KAYE",       // Bad Bunny -> ALEX_KAYE (남성)
            "eminem_singer": "ALEX_KAYE",          // Eminem -> ALEX_KAYE (남성)
            "kanye_west_singer": "ALEX_KAYE",      // Kanye West -> ALEX_KAYE (남성)
            "21_savage_singer": "ALEX_KAYE",       // 21 Savage -> ALEX_KAYE (남성)
            "morgan_wallen_singer": "ALEX_KAYE",   // Morgan Wallen -> ALEX_KAYE (남성)
            "louis_armstrong_singer": "ALEX_KAYE", // Louis Armstrong -> ALEX_KAYE (남성)
            "elvis_presley_singer": "ALEX_KAYE",   // Elvis Presley -> ALEX_KAYE (남성)
            "frank_sinatra_singer": "ALEX_KAYE",   // Frank Sinatra -> ALEX_KAYE (남성)
            
            // Female Artists (여성 가수)
            "lady_gaga_singer": "STASIA_FAYE",     // Lady Gaga -> STASIA_FAYE (여성)
            "taylor_swift_singer": "STASIA_FAYE",  // Taylor Swift -> STASIA_FAYE (여성)
            "beyonce_singer": "STASIA_FAYE",       // Beyoncé -> STASIA_FAYE (여성)
            "adele_singer": "STASIA_FAYE",         // Adele -> STASIA_FAYE (여성)
            
            // K-Pop Artists (K-Pop 가수)
            "bts_singer": "ALEX_KAYE",             // BTS -> ALEX_KAYE (남성 그룹)
            "blackpink_singer": "STASIA_FAYE",     // BLACKPINK -> STASIA_FAYE (여성 그룹)
            "twice_singer": "STASIA_FAYE",         // TWICE -> STASIA_FAYE (여성 그룹)
            "exo_singer": "ALEX_KAYE",             // EXO -> ALEX_KAYE (남성 그룹)
            
            // 기본 음성들 (직접 매핑)
            "ALEX_KAYE": "ALEX_KAYE",              // 남성 기본 음성
            "STASIA_FAYE": "STASIA_FAYE",          // 여성 기본 음성
            "NICOLAAS_HAAS": "NICOLAAS_HAAS",      // 남성 음성
            "NIK_ZEL": "NIK_ZEL",                  // 남성 음성
            "OLIA_CHEBO": "OLIA_CHEBO",            // 여성 음성
            "YVAR_DE_GROOT": "YVAR_DE_GROOT",      // 남성 음성
            "VETRANA": "VETRANA"                   // 여성 음성
        ]
        
        // 지원되지 않는 가수는 기본 남성 음성 사용
        let defaultVoice = "ALEX_KAYE"
        
        let voiceId = singerVoiceMapping[singerVoiceId] ?? defaultVoice
        print("✅ Mapped singer \(singerVoiceId) -> LALAL.AI voice ID: \(voiceId)")
        
        return voiceId
    }
    
    private func trimAudioToDuration(_ audioData: Data, duration: TimeInterval) async throws -> Data {
        print("✂️ Trimming audio to \(duration) seconds")
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.mp3")
        try audioData.write(to: tempURL)
        
        // Create asset
        let asset = AVAsset(url: tempURL)
        
        // Create export session with MP3 preset
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VoiceConversionError.invalidAudioData
        }
        
        // Set output URL
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed_audio.m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Set time range (0 to duration)
        let startTime = CMTime.zero
        let endTime = CMTime(seconds: duration, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        exportSession.timeRange = timeRange
        
        // Export
        await exportSession.export()
        
        // Check export status
        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw VoiceConversionError.serverError("Export failed: \(error.localizedDescription)")
            } else {
                throw VoiceConversionError.serverError("Export failed with unknown error")
            }
        }
        
        // Read trimmed audio data
        let trimmedData = try Data(contentsOf: outputURL)
        
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: outputURL)
        
        print("✅ Audio trimmed successfully")
        print("   Original size: \(audioData.count) bytes")
        print("   Trimmed size: \(trimmedData.count) bytes")
        
        return trimmedData
    }
}

// MARK: - Audio Trimming Helper
func trimAudioToDuration(_ audioData: Data, duration: TimeInterval) async throws -> Data {
    print("✂️ Trimming audio to \(duration) seconds")
    
    // Create temporary file
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.mp3")
    try audioData.write(to: tempURL)
    
    // Create asset
    let asset = AVAsset(url: tempURL)
    
    // Create export session with MP3 preset
    guard let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetAppleM4A
    ) else {
        throw VoiceConversionError.invalidAudioData
    }
    
    // Set output URL
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed_audio.m4a")
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    
    // Set time range (0 to duration)
    let startTime = CMTime.zero
    let endTime = CMTime(seconds: duration, preferredTimescale: 600)
    let timeRange = CMTimeRange(start: startTime, end: endTime)
    exportSession.timeRange = timeRange
    
    // Export
    await exportSession.export()
    
    // Check export status
    guard exportSession.status == .completed else {
        if let error = exportSession.error {
            throw VoiceConversionError.serverError("Export failed: \(error.localizedDescription)")
        } else {
            throw VoiceConversionError.serverError("Export failed with unknown error")
        }
    }
    
    // Read trimmed audio data
    let trimmedData = try Data(contentsOf: outputURL)
    
    // Clean up temporary files
    try? FileManager.default.removeItem(at: tempURL)
    try? FileManager.default.removeItem(at: outputURL)
    
    print("✅ Audio trimmed successfully")
    print("   Original size: \(audioData.count) bytes")
    print("   Trimmed size: \(trimmedData.count) bytes")
    
    return trimmedData
}

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

// MARK: - Voice Conversion Errors
enum VoiceConversionError: LocalizedError {
    case serverError(String)
    case invalidAudioData
    case timeout
    case lalalAIError(LalalAIError)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .invalidAudioData:
            return "Invalid audio data received"
        case .timeout:
            return "Voice conversion timed out"
        case .lalalAIError(let error):
            return "LALAL.AI 오류: \(error.localizedDescription)"
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

// MARK: - Voice Conversion Models

struct VoiceInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let previewUrl: String?
    let language: [String]?
    let voiceType: String? // "default", "singer", "custom"
    
    init(id: String, name: String, category: String, description: String?, previewUrl: String?, language: [String]? = nil, voiceType: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.previewUrl = previewUrl
        self.language = language
        self.voiceType = voiceType
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "voiceId"
        case name
        case category
        case description
        case previewUrl = "preview_url"
        case language
        case voiceType
    }
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Album Art View
struct AlbumArtView: View {
    let albumArt: UIImage?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let albumArt = albumArt {
            Image(uiImage: albumArt)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 320, height: 320)
                .cornerRadius(24)
                .shadow(radius: 14)
        } else {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 320, height: 320)
                .cornerRadius(24)
        }
    }
}

// MARK: - Player Controls
struct PlayerControlsView: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack(spacing: 56) {
            ZStack {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Circle()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 8, height: 8)
                    .offset(x: 22, y: 10)
            }
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            ZStack {
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Circle()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 8, height: 8)
                    .offset(x: -22, y: 10)
            }
        }
    }
}

// MARK: - Custom Remix/AI Toggle (Figma 스타일)
struct RemixAIToggle: View {
    @Binding var isAIVersion: Bool
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let circleSize = height * 0.8
            let circleOffset = isAIVersion ? width - circleSize - 4 : 4
            
            ZStack {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                    .offset(x: circleOffset - width / 2 + circleSize / 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAIVersion)
                HStack {
                    Text("REMIX")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAIVersion ? .white.opacity(0.5) : .white)
                        .animation(.easeInOut(duration: 0.2), value: isAIVersion)
                    
                    Spacer()
                    
                    Text("AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isAIVersion ? .white : .white.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: isAIVersion)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(width: 120, height: 32)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAIVersion.toggle()
            }
        }
    }
}

struct Artist {
    let id: UUID = UUID()
    let name: String
    let imageName: String 
}

@MainActor
struct PlayerView: View {
    let store: Store<PlayerReducer.State, PlayerReducer.Action>
    @Binding var isMiniPlayerVisible: Bool
    let libraryStore: StoreOf<LibraryReducer>
    let albumArtNamespace: Namespace.ID
    @State private var isDetailViewPresented = false
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var audioManager = AudioManager.shared
    @State private var isRemixSheetPresented = false
    @State private var selectedArtists: [Artist] = []
    @State private var isAddToPlaylistSheetPresented = false
    @State private var isPlaylistSelectSheetPresented = false
    @State private var showAddSuccess = false
    let mockArtists: [Artist] = [
        Artist(name: "Dua Lipa", imageName: "artist_dualipa"),
        Artist(name: "BlackPink", imageName: "artist_blackpink"),
        Artist(name: "H.E.R", imageName: "artist_her"),
        Artist(name: "Rihanna", imageName: "artist_rihanna")
    ]
    
    @State private var showIMSLPList = false 
    @State private var isRemixing = false
    @State private var remixedAudioURL: URL? = nil
    @State private var isAIVersion: Bool = false
    @State private var showNoMatchAlert = false
    
    @State private var isVoiceConverting = false
    @State private var showVoiceSelectionSheet = false
    @State private var availableVoices: [VoiceInfo] = []
    @State private var selectedVoice: VoiceInfo?
    @State private var showVoiceConversionError = false
    @State private var voiceConversionErrorMessage = ""
    
    struct ViewState: Equatable {
        let isPlaying: Bool
        let isAIMusicEnabled: Bool
        let currentTrack: PlayableTrackDTO?
        let playlist: [PlayableTrackDTO]
        let currentIndex: Int
        
        init(state: PlayerReducer.State) {
            self.isPlaying = state.isPlaying
            self.isAIMusicEnabled = state.isAIMusicEnabled
            self.currentTrack = state.currentTrack
            self.playlist = state.playlist
            self.currentIndex = state.currentIndex
        }
    }
    
    var combinedArtistLabel: String {
        let base = audioManager.currentTrackMetadata.artist ?? ""
        let baseArtists = base.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        let remixNames = selectedArtists.map { $0.name }
        let all = (baseArtists + remixNames).filter { !$0.isEmpty }
        let unique = Array(NSOrderedSet(array: all)) as? [String] ?? all
        return unique.joined(separator: " + ")
    }
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in
            ZStack {
                Color(hex: "#63477C")
                    .ignoresSafeArea()
                LinearGradient(
                    gradient: Gradient(colors: [Color.red.opacity(0.2), Color.purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let track = viewStore.currentTrack {
                        if let artworkURL = track.artworkURL {
                            AsyncImage(url: artworkURL) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 320, height: 320)
                            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                            .cornerRadius(24)
                            .shadow(radius: 14)
                            .padding(.bottom, 8)
                        } else {
                            AlbumArtView(albumArt: audioManager.currentTrackMetadata.albumArt)
                                .frame(width: 320, height: 320)
                                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                                .cornerRadius(24)
                                .shadow(radius: 14)
                                .padding(.bottom, 8)
                        }
                        
                        VStack(spacing: 2) {
                            HStack(alignment: .center) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {/* TODO: Like */}) {
                                    Image(systemName: "heart")
                                        .foregroundColor(.white)
                                }
                                Button(action: { isPlaylistSelectSheetPresented = true }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal)
                            Text(track.artistName ?? "")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    } else {
                        AlbumArtView(albumArt: nil)
                            .frame(width: 320, height: 320)
                            .cornerRadius(24)
                            .shadow(radius: 14)
                            .padding(.bottom, 8)
                        VStack(spacing: 2) {
                            HStack(alignment: .center) {
                                Text("로딩 중...")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal)
                            Text("")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    }
                    
                    VStack(spacing: 0) {
                        if audioManager.duration > 0 {
                            Slider(value: $audioManager.currentTime, in: 0...audioManager.duration, onEditingChanged: { editing in
                                if !editing {
                                    Task {
                                        await audioManager.seek(to: audioManager.currentTime)
                                    }
                                }
                            })
                            .accentColor(.white)
                        } else {
                            Slider(value: .constant(0), in: 0...1)
                                .disabled(true)
                        }
                        HStack {
                            Text(formatTime(audioManager.currentTime))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {/* TODO: Show Lyrics */}) {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                Text("가사보기")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .clipShape(Capsule())
                        }
                        Button(action: {/* TODO: Show Artist Info */}) {
                            HStack(spacing: 6) {
                                Image(systemName: "person")
                                let artist = audioManager.currentTrackMetadata.artist ?? ""
                                Text("")
                                Text("\(artist)에 대해 더 알아보기")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 18) {
                            Button(action: {
                                if let currentTitle = audioManager.currentTrackMetadata.title?.lowercased(),
                                   let currentArtist = audioManager.currentTrackMetadata.artist?.lowercased(),
                                   let demoTrack = demoTracks.first(where: {
                                       $0.title.lowercased() == currentTitle && $0.artist.lowercased() == currentArtist
                                   }) {
                                    isRemixing = true
                                    remixDemoTrack(demoTrack) { result in
                                        DispatchQueue.main.async {
                                            isRemixing = false
                                            switch result {
                                            case .success(let url):
                                                // 변환된 AI 트랙을 PlayerReducer로 흘려 MiniPlayer/컨트롤 상태 일관화
                                                let track = PlayableTrackDTO(
                                                    id: UUID(),
                                                    title: demoTrack.title,
                                                    artistName: demoTrack.artist,
                                                    playbackUrl: nil,
                                                    playbackStoreID: nil,
                                                    isAIGenerated: true,
                                                    duration: nil,
                                                    fileUrl: url.absoluteString,
                                                    artworkURL: nil
                                                )
                                                viewStore.send(.startPlayback([track]))
                                            case .failure(let error):
                                                print("AI 변환 실패: \(error)")
                                            }
                                        }
                                    }
                                } else {
                                    // 내장곡이 아니면 안내
                                    showNoMatchAlert = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "music.note")
                                    Text("Remix")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(viewStore.isAIMusicEnabled ? 0.7 : 0.25), lineWidth: 2)
                                        .background(
                                            viewStore.isAIMusicEnabled ? Color.purple.opacity(0.7).cornerRadius(24) : Color.clear.cornerRadius(24)
                                        )
                                )
                            }
                            .disabled(!viewStore.isAIMusicEnabled)
                            .opacity(viewStore.isAIMusicEnabled ? 1 : 0.4)
                            
                            Button(action: {
                                Task {
                                    await loadAvailableVoices()
                                }
                                showVoiceSelectionSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.wave.2")
                                    Text("Voice")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                        .background(Color.blue.opacity(0.7).cornerRadius(24))
                                )
                            }
                        }
                       // TODO: remix & ai 토글 디자인 
                        // RemixAIToggle(isAIVersion: Binding(
                        //     get: { viewStore.isAIMusicEnabled },
                        //     set: { newValue in viewStore.send(.toggleAIMusic(newValue)) }
                        // ))
                        // .frame(width: 180)
                    }
                    .padding(.bottom, 28)
                    
                    PlayerControlsView(
                        isPlaying: viewStore.isPlaying,
                        onPrevious: { viewStore.send(.previousTrack) },
                        onPlayPause: { viewStore.send(.playPause) },
                        onNext: { viewStore.send(.nextTrack) }
                    )
                    .padding(.top, 18)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                
                if isRemixing {
                    ProgressView("AI 변환/리믹스 중...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .zIndex(100)
                }
                
                if isVoiceConverting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("음성 변환 중...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text("최대 5분 정도 소요될 수 있습니다")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .zIndex(100)
                }
            }
            .onAppear {
                viewStore.send(.syncPlaybackState)
                if !viewStore.isPlaying {
                    viewStore.send(.playPause)
                }
                libraryStore.send(.fetchUserPlaylists)
            }
            .onReceive(NotificationCenter.default.publisher(for: AudioManager.audioDidFinishNotification)) { _ in
                viewStore.send(.audioDidFinish)
            }
            .sheet(isPresented: $isPlaylistSelectSheetPresented, onDismiss: {
                libraryStore.send(.fetchUserPlaylists)
            }) {
                let playlists = ViewStore(libraryStore, observe: { $0.playlists }).state
                if let track = viewStore.currentTrack {
                }
            }
            .alert("플레이리스트에 추가되었습니다!", isPresented: $showAddSuccess) {
                Button("확인", role: .cancel) { showAddSuccess = false }
            }
            
            .alert("퍼블릭 도메인 곡을 찾을 수 없습니다.", isPresented: $showNoMatchAlert) {
                Button("확인", role: .cancel) { showNoMatchAlert = false }
            }
            
            .alert("음성 변환 실패", isPresented: $showVoiceConversionError) {
                Button("확인", role: .cancel) { showVoiceConversionError = false }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .sheet(isPresented: $showVoiceSelectionSheet) {
                VoiceSelectionSheet(
                    voices: availableVoices,
                    onVoiceSelected: { voice in
                        selectedVoice = voice
                        showVoiceSelectionSheet = false
                        performVoiceConversion(with: voice)
                    },
                    onCancel: {
                        showVoiceSelectionSheet = false
                    }
                )
            }
            .sheet(isPresented: $isAddToPlaylistSheetPresented) {
                AddToPlaylistSheet(
                    playlist: PlaylistSummaryDTO(
                        id: UUID(),
                        name: "Current Track",
                        user: nil
                    ),
                    onAdd: { _ in
                        isAddToPlaylistSheetPresented = false
                    }
                )
            }
            .alert("음성 변환 오류", isPresented: $showVoiceConversionError) {
                Button("확인") { }
            } message: {
                Text(voiceConversionErrorMessage)
            }
            .overlay(
                Group {
                    if isVoiceConverting {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("음성을 변환하고 있습니다...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.top, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.7))
                    }
                }
            )
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    struct LocalDemoTrack: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let artist: String
        let fileName: String 
    }
    
    let demoTracks: [LocalDemoTrack] = [
        LocalDemoTrack(title: "Fix You", artist: "Coldplay", fileName: "fixyou.mp3"),
        LocalDemoTrack(title: "Feels Like Falling In Love", artist: "Coldplay", fileName: "feelslikefallinginlove.mp3")
    ]
    
    func remixDemoTrack(_ track: LocalDemoTrack, completion: @escaping (Result<URL, Error>) -> Void) {
        if let fileURL = Bundle.main.url(forResource: track.fileName, withExtension: nil) {
            uploadFileToAIConvert(fileURL: fileURL, completion: completion)
        } else {
            completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "내장 mp3 파일을 찾을 수 없습니다."])))
        }
    }
    
    func uploadFileToAIConvert(fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // LALAL.AI 직접 호출 (기본 남성 음성 ALEX_KAYE 사용)
        Task {
            do {
                let audioData = try Data(contentsOf: fileURL)
                let convertedAudioData = try await voiceConversionService.performLalalAIVoiceChange(
                    audioData: audioData,
                    voiceId: "ALEX_KAYE"
                )
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ai_version.mp3")
                try convertedAudioData.write(to: tempURL)
                await MainActor.run { completion(.success(tempURL)) }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }
    
    @MainActor
    private func loadAvailableVoices() async {
        // LALAL.AI Legal Voice Packs (iOS 로컬 목록)
        availableVoices = [
            VoiceInfo(id: "ALEX_KAYE",     name: "Alex Kaye",     category: "Default", description: "남성 기본 음성", previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "STASIA_FAYE",   name: "Stasia Faye",   category: "Default", description: "여성 기본 음성", previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "NICOLAAS_HAAS", name: "Nicolaas Haas", category: "Default", description: "남성 음성",     previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "NIK_ZEL",       name: "Nik Zel",       category: "Default", description: "남성 음성",     previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "YVAR_DE_GROOT", name: "Yvar De Groot", category: "Default", description: "남성 음성",     previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "OLIA_CHEBO",    name: "Olia Chebo",    category: "Default", description: "여성 음성",     previewUrl: nil, language: ["en"], voiceType: "default"),
            VoiceInfo(id: "VETRANA",       name: "Vetrana",       category: "Default", description: "여성 음성",     previewUrl: nil, language: ["en"], voiceType: "default")
        ]
        print("✅ Loaded \(availableVoices.count) local LALAL.AI voice packs")
    }
    
    private func performVoiceConversion(with voice: VoiceInfo, shouldTrim: Bool = false, trimDuration: Double = 120.0) {
        // PlayerReducer 상태(selected track) 우선, AudioManager 메타는 보조
        let reducerTrack = ViewStore(store, observe: { $0.currentTrack }).state
        let audioMeta = audioManager.currentTrackMetadata
        let resolvedTitle = reducerTrack?.title ?? audioMeta.title
        let resolvedArtist = reducerTrack?.artistName ?? audioMeta.artist

        guard resolvedTitle != nil || resolvedArtist != nil else {
            showVoiceConversionError = true
            voiceConversionErrorMessage = "현재 재생 중인 트랙이 없습니다."
            return
        }

        isVoiceConverting = true

        Task {
            do {
                let audioData: Data = try await resolveAudioData(reducerTrack: reducerTrack, title: resolvedTitle)
                
                let trimmedAudioData: Data
                if shouldTrim {
                    trimmedAudioData = try await trimAudioToDuration(audioData, duration: trimDuration)
                } else {
                    trimmedAudioData = audioData
                    print("🎵 Using full audio data for voice conversion (\(audioData.count) bytes)")
                }
                
                let convertedAudioData = try await performDirectLalalAIVoiceConversion(
                    audioData: trimmedAudioData,
                    voiceId: voice.id,
                    voiceType: voice.voiceType
                )
                
                // Save converted audio
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "voice_converted_\(voice.name).mp3"
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                try convertedAudioData.write(to: fileURL)
                
                // print("✅ Voice conversion successful, saved to: \(fileURL)")
                
                let asset = AVAsset(url: fileURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                await MainActor.run {
                    // PlayerReducer를 통해 재생 (playerState 유지 → MiniPlayer 표시됨)
                    let track = PlayableTrackDTO(
                        id: UUID(),
                        title: "\(resolvedTitle ?? "Unknown") (Voice: \(voice.name))",
                        artistName: resolvedArtist ?? "Unknown Artist",
                        playbackUrl: nil,
                        playbackStoreID: nil,
                        isAIGenerated: true,
                        duration: durationSeconds.isFinite ? durationSeconds : nil,
                        fileUrl: fileURL.path,
                        artworkURL: nil
                    )
                    store.send(.startPlayback([track]))

                    isVoiceConverting = false
                }
                
            } catch {
                await MainActor.run {
                    isVoiceConverting = false
                    showVoiceConversionError = true
                    voiceConversionErrorMessage = "음성 변환에 실패했습니다: \(error.localizedDescription)"
                    print("❌ AI music playback error: \(error)")
                }
            }
        }
    }
    
    private func performDirectLalalAIVoiceConversion(
        audioData: Data,
        voiceId: String,
        voiceType: String?
    ) async throws -> Data {
        let isSingerVoice = voiceId.contains("_singer") || voiceType == "singer"

        if isSingerVoice {
            return try await voiceConversionService.performLalalAIVoiceChange(audioData: audioData, voiceId: voiceId)
        } else {
            return try await voiceConversionService.performLalalAIVoiceChange(audioData: audioData, voiceId: voiceId)
        }
    }

    /// Resolve audio Data for voice conversion.
    /// Order: currently-playing AVPlayer URL → AI track fileUrl → Apple Music preview (via playbackStoreID or title search) → bundled demo.
    private func resolveAudioData(reducerTrack: PlayableTrackDTO?, title: String?) async throws -> Data {
        // 1. Currently playing via AudioManager
        if let currentURL = audioManager.currentAudioURL {
            print("🎵 VoiceConversion: using currentAudioURL=\(currentURL)")
            return try Data(contentsOf: currentURL)
        }

        // 2. AI track local fileUrl
        if let track = reducerTrack, track.isAIGenerated, let fileUrlString = track.fileUrl {
            let url: URL? = {
                if fileUrlString.hasPrefix("file://") { return URL(string: fileUrlString) }
                if fileUrlString.hasPrefix("/") { return URL(fileURLWithPath: fileUrlString) }
                return URL(string: fileUrlString)
            }()
            if let url = url {
                print("🎵 VoiceConversion: using AI track fileUrl=\(url)")
                return try Data(contentsOf: url)
            }
        }

        // 3. Apple Music preview via MusicKit
        if let previewURL = try await fetchApplePreviewURL(reducerTrack: reducerTrack, fallbackTitle: title) {
            print("🎵 VoiceConversion: downloading Apple Music preview=\(previewURL)")
            let (data, _) = try await URLSession.shared.data(from: previewURL)
            return data
        }

        // 4. Last resort: bundled demo sample
        if let demoURL = Bundle.main.url(forResource: "fixyou", withExtension: "mp3") {
            print("⚠️ VoiceConversion: falling back to bundled demo sample")
            return try Data(contentsOf: demoURL)
        }

        throw VoiceConversionError.invalidAudioData
    }

    private func fetchApplePreviewURL(reducerTrack: PlayableTrackDTO?, fallbackTitle: String?) async throws -> URL? {
        let song: MusicKit.Song?
        if let storeID = reducerTrack?.playbackStoreID, !storeID.isEmpty {
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(storeID))
            let response = try await request.response()
            song = response.items.first
        } else if let searchTerm = fallbackTitle, !searchTerm.isEmpty {
            let request = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
            let response = try await request.response()
            song = response.songs.first
        } else {
            song = nil
        }
        return song?.previewAssets?.first?.url
    }
}

struct VoiceSelectionSheet: View {
    let voices: [VoiceInfo]
    let onVoiceSelected: (VoiceInfo) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    
    var filteredVoices: [VoiceInfo] {
        if searchText.isEmpty {
            return voices
        } else {
            return voices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.description?.localizedCaseInsensitiveContains(searchText) == true ||
                voice.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var groupedVoices: [String: [VoiceInfo]] {
        Dictionary(grouping: filteredVoices) { voice in
            voice.category
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("음성 선택")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField("음성 검색", text: $searchText)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(groupedVoices.keys.sorted()), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 24)
                                
                                ForEach(groupedVoices[category] ?? [], id: \.id) { voice in
                                    VoiceRowView(voice: voice) {
                                        onVoiceSelected(voice)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                Spacer(minLength: 0)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.85), Color.purple.opacity(0.7)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(24)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onTapGesture {
            onCancel()
        }
    }
}

struct VoiceRowView: View {
    let voice: VoiceInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(voice.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let voiceType = voice.voiceType {
                            Text(voiceType == "singer" ? "🎤" : "🎵")
                                .font(.system(size: 14))
                        }
                    }
                    
                    if let description = voice.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text(voice.category)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        if let language = voice.language, !language.isEmpty {
                            Text("• \(language.joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
