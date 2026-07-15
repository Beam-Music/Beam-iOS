//
//  VoiceConversionProviders.swift
//  BeamApp
//
//  Extracted from PlayerView.swift for better code organization.
//

import SwiftUI
import AVFoundation

// MARK: - Voice Conversion Provider Abstraction (Phase 0)
// docs/SVC_MIGRATION.md 참조. lalal.ai에서 자체 Beam SVC 백엔드로 점진 전환하기 위한 추상화.

/// 음성 변환 제공자 추상화. 호출부는 이 프로토콜만 사용한다.
protocol VoiceConversionProvider {
    /// 보컬 변환 수행. `voiceType`은 "singer" / "default" / "custom" / nil.
    func convert(audioData: Data, voiceId: String, voiceType: String?, trimStart: Double?, trimDuration: Double?) async throws -> Data
}

enum VoiceProviderKind: String {
    case lalalAI = "lalal_ai"
    case beamSVC = "beam_svc"
    case kitsAI = "kits_ai"
}

/// 런타임 스위칭용 설정.
/// - legacy: `voice_conversion.use_beam_svc`
/// - current: `voice_conversion.provider`
enum VoiceConversionConfig {
    private static let useBeamSVCKey = "voice_conversion.use_beam_svc"
    private static let providerKey = "voice_conversion.provider"

    static var currentProvider: VoiceProviderKind {
        get { .beamSVC }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
            UserDefaults.standard.set(true, forKey: useBeamSVCKey)
        }
    }

    static var useBeamSVC: Bool {
        get { true }
        set { currentProvider = .beamSVC }
    }

    static func makeProvider() -> VoiceConversionProvider {
        print("🧭 VoiceConversionConfig.makeProvider -> BeamSVCVoiceConversionProvider")
        return BeamSVCVoiceConversionProvider()
    }
}

/// 호출부에서 사용하는 단일 진입점. 현재 설정에 맞는 Provider를 매번 반환.
var voiceConversionService: VoiceConversionProvider {
    VoiceConversionConfig.makeProvider()
}

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

/// 기존 lalal.ai 기반 구현 (Phase 0 이전의 인라인 코드를 리네임만 함).
/// 동작은 100% 동일. 향후 자체 백엔드로 완전 이관되면 deprecate 예정.
final class LalalAIVoiceConversionProvider: VoiceConversionProvider {

    // MARK: - VoiceConversionProvider
    func convert(audioData: Data, voiceId: String, voiceType: String?, trimStart: Double?, trimDuration: Double?) async throws -> Data {
        // 기존 동작 그대로: voiceType/trim 파라미터는 lalal 경로에서 사용되지 않음
        return try await performLalalAIVoiceChange(audioData: audioData, voiceId: voiceId)
    }

    // MARK: - 기존 메서드 (호환성 유지)
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
                let maxAllowedSeconds = maxAllowedDuration
                
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
func trimAudioToDuration(_ audioData: Data, duration: TimeInterval, startTime: TimeInterval = 0) async throws -> Data {
    print("✂️ Trimming audio from \(startTime)s for \(duration) seconds")
    
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
    
    // Set time range
    let start = CMTime(seconds: startTime, preferredTimescale: 600)
    let endTime = CMTime(seconds: startTime + duration, preferredTimescale: 600)
    let timeRange = CMTimeRange(start: start, end: endTime)
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

struct ConvertedVoiceTrackRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let artistName: String?
    let voiceId: String?
    let voiceName: String
    let filePath: String
    let artworkURL: String?
    let createdAt: Date
}

enum ConvertedVoiceTrackStore {
    private static var manifestURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("converted_voice_tracks.json")
    }

    static func load() -> [ConvertedVoiceTrackRecord] {
        guard let data = try? Data(contentsOf: manifestURL) else { return [] }
        let records = (try? JSONDecoder().decode([ConvertedVoiceTrackRecord].self, from: data)) ?? []
        return deduplicated(records)
    }

    @discardableResult
    static func save(
        title: String,
        artistName: String?,
        voiceId: String? = nil,
        voiceName: String,
        filePath: String,
        artworkURL: URL?
    ) throws -> ConvertedVoiceTrackRecord {
        let record = ConvertedVoiceTrackRecord(
            id: UUID(),
            title: title,
            artistName: artistName,
            voiceId: voiceId,
            voiceName: voiceName,
            filePath: filePath,
            artworkURL: artworkURL?.absoluteString,
            createdAt: Date()
        )

        let newKey = deduplicationKey(for: record)
        var records = load().filter {
            $0.filePath != filePath && deduplicationKey(for: $0) != newKey
        }
        records.insert(record, at: 0)

        let data = try JSONEncoder().encode(records)
        try data.write(to: manifestURL, options: .atomic)
        return record
    }

    private static func deduplicated(_ records: [ConvertedVoiceTrackRecord]) -> [ConvertedVoiceTrackRecord] {
        var seenKeys = Set<String>()
        var unique: [ConvertedVoiceTrackRecord] = []

        for record in records.sorted(by: { $0.createdAt > $1.createdAt }) {
            let key = deduplicationKey(for: record)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            unique.append(record)
        }

        return unique
    }

    private static func deduplicationKey(for record: ConvertedVoiceTrackRecord) -> String {
        let voiceKey = record.voiceId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ?? normalized(record.voiceName)
        return "\(normalized(record.title))::\(normalized(record.artistName ?? ""))::\(voiceKey)"
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func delete(id: UUID) {
        let records = load()
        if let record = records.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(atPath: record.filePath)
        }
        let updated = records.filter { $0.id != id }
        if let data = try? JSONEncoder().encode(updated) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    static func deleteAll() {
        let records = load()
        for record in records {
            try? FileManager.default.removeItem(atPath: record.filePath)
        }
        try? FileManager.default.removeItem(at: manifestURL)
    }
}

extension ConvertedVoiceTrackRecord {
    func toPlayableTrack() -> PlayableTrackDTO {
        PlayableTrackDTO(
            id: UUID(),
            title: title,
            artistName: artistName,
            playbackUrl: nil,
            playbackStoreID: nil,
            isAIGenerated: true,
            duration: nil,
            fileUrl: filePath,
            artworkURL: artworkURL.flatMap(URL.init(string:))
        )
    }
}

// MARK: - Beam 자체 SVC Provider

/// 자체 백엔드 (`/ai-convert/voice-conversion`) 기반 구현.
/// docs/SVC_MIGRATION.md Phase 0을 위해 BeamApp/Network/VoiceConversionClient.swift의 multipart 로직을 이식함.
final class BeamSVCVoiceConversionProvider: VoiceConversionProvider {

    struct AsyncJobResponse: Decodable {
        let jobId: String
        let status: String
    }

    struct AsyncJobStatusResponse: Decodable {
        let jobId: String
        let status: String
        let progress: Int
        let stage: String?
        let resultUrl: String?
        let resultPath: String?
        let error: String?
    }

    private let maxRetries = 3

    func convert(audioData: Data, voiceId: String, voiceType: String?, trimStart: Double?, trimDuration: Double?) async throws -> Data {
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                // Always use the async job endpoint for Beam SVC conversions. Full-song RVC
                // conversion can exceed URLSession's request idle timeout if we wait for
                // the audio response directly, especially for heavier voices like Lil Wayne.
                let jobData = try await performRequest(
                    audioData: audioData,
                    voiceId: voiceId,
                    voiceType: voiceType,
                    outputFormat: "mp3",
                    trimStart: trimStart,
                    trimDuration: trimDuration,
                    returnJob: true
                )
                let job = try JSONDecoder().decode(AsyncJobResponse.self, from: jobData)
                return try await pollJobUntilFinished(jobId: job.jobId)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delayNs = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delayNs)
                    continue
                }
                throw error
            }
        }
        throw lastError ?? VoiceConversionError.timeout
    }

    func submitAsyncJob(
        audioData: Data,
        voiceId: String,
        voiceType: String?,
        trimStart: Double? = nil,
        trimDuration: Double? = nil
    ) async throws -> AsyncJobResponse {
        let data = try await performRequest(
            audioData: audioData,
            voiceId: voiceId,
            voiceType: voiceType,
            outputFormat: "mp3",
            trimStart: trimStart,
            trimDuration: trimDuration,
            returnJob: true
        )
        return try JSONDecoder().decode(AsyncJobResponse.self, from: data)
    }

    func pollJobUntilFinished(jobId: String, pollInterval: UInt64 = 2_000_000_000, onProgress: ((Int, String?) -> Void)? = nil) async throws -> Data {
        guard let statusURL = URL(string: "\(Endpoints.beamSVCBaseURL)/ai-convert/jobs/\(jobId)") else {
            throw VoiceConversionError.serverError("Invalid Beam SVC job URL")
        }

        while true {
            let (data, _) = try await URLSession.shared.data(from: statusURL)
            let status = try JSONDecoder().decode(AsyncJobStatusResponse.self, from: data)
            switch status.status {
            case "completed":
                guard let resultURL = URL(string: "\(Endpoints.beamSVCBaseURL)/ai-convert/results/\(jobId)") else {
                    throw VoiceConversionError.serverError("Beam SVC result URL is missing.")
                }
                let (resultData, _) = try await URLSession.shared.data(from: resultURL)
                return resultData
            case "failed":
                throw VoiceConversionError.serverError(status.error ?? "Beam SVC async job failed")
            default:
                onProgress?(status.progress, status.stage)
                try await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }

    private func performRequest(
        audioData: Data,
        voiceId: String,
        voiceType: String?,
        outputFormat: String,
        trimStart: Double?,
        trimDuration: Double?,
        returnJob: Bool
    ) async throws -> Data {
        guard let url = URL(string: Endpoints.VoiceConversion.convert) else {
            throw VoiceConversionError.serverError("Invalid Beam SVC URL")
        }
        print("🌐 Beam SVC convert URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1800 // 30 min

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // source_audio
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source_audio\"; filename=\"audio.mp3\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // voiceId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voiceId\"\r\n\r\n".data(using: .utf8)!)
        body.append(voiceId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // voiceType (singer일 때만 전송)
        if let voiceType = voiceType, voiceType == "singer" {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voiceType\"\r\n\r\n".data(using: .utf8)!)
            body.append(voiceType.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        // language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // preserve_melody
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"preserve_melody\"\r\n\r\n".data(using: .utf8)!)
        body.append("true".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        if let trimStart {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"trim_start\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(trimStart)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        if let trimDuration {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"trim_duration\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(trimDuration)".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        if returnJob {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"return_job\"\r\n\r\n".data(using: .utf8)!)
            body.append("true".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1800
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceConversionError.serverError("Could not verify the Beam SVC response.")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = (json["message"] as? String) ?? (json["error"] as? String) ?? "Beam SVC HTTP \(httpResponse.statusCode)"
                throw VoiceConversionError.serverError(message)
            }
            throw VoiceConversionError.serverError("Beam SVC HTTP \(httpResponse.statusCode)")
        }

        if returnJob {
            return data
        }

        // JSON이면 에러, 그 외엔 오디오 바이너리
        if let s = String(data: data, encoding: .utf8), s.hasPrefix("{") {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = (json["error"] as? String) ?? (json["reason"] as? String) ?? "Unknown error"
                throw VoiceConversionError.serverError(message)
            }
            throw VoiceConversionError.serverError("Invalid JSON response")
        }

        guard data.count > 1000 else {
            throw VoiceConversionError.invalidAudioData
        }
        return data
    }
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
            return "LALAL.AI error: \(error.localizedDescription)"
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

extension VoiceInfo {
    var englishCategory: String {
        switch category {
        case "남성 기본": return "Default Male"
        case "여성 기본": return "Default Female"
        case "유명인": return "Celebrity"
        case "캐릭터/유명인": return "Character / Celebrity"
        default: return category
        }
    }

    var englishDescription: String? {
        switch id {
        case "dionn_v1_singing": return "Male singing voice"
        case "freya_idol": return "Female idol-style vocal voice"
        case "taylor_swift_singer": return "Singer-style pop vocal"
        case "the_weeknd": return "The Weeknd-style male pop vocal"
        case "ariana_grande": return "Ariana Grande-style female pop vocal"
        case "lil_wayne": return "Lil Wayne-style male rap vocal"
        case "drake": return "Drake-style male rap vocal"
        default: return description
        }
    }

    var avatarInitials: String {
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "♪" : initials.uppercased()
    }

    var artistImageURL: URL? {
        let urlString: String?
        switch id {
        case "drake":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Drake_at_The_Carter_Effect_2017_%2836818935200%29_%28cropped%29.jpg/330px-Drake_at_The_Carter_Effect_2017_%2836818935200%29_%28cropped%29.jpg"
        case "lil_wayne":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Lil_Wayne_Feb._2020.jpg/330px-Lil_Wayne_Feb._2020.jpg"
        case "the_weeknd":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/The_Weeknd_Portrait_by_Brian_Ziff.jpg/330px-The_Weeknd_Portrait_by_Brian_Ziff.jpg"
        case "ariana_grande":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Ariana_Grande_promoting_Wicked_%282024%29.jpg/330px-Ariana_Grande_promoting_Wicked_%282024%29.jpg"
        case "taylor_swift_singer":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Taylor_Swift_at_the_2023_MTV_Video_Music_Awards_%283%29.png/330px-Taylor_Swift_at_the_2023_MTV_Video_Music_Awards_%283%29.png"
        case "kehlani":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Kehlani-New-Zealand-Warner-Music-Interview.png/330px-Kehlani-New-Zealand-Warner-Music-Interview.png"
        case "bad_bunny":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Bad_Bunny_2019_by_Glenn_Francis_%28cropped%29.jpg/330px-Bad_Bunny_2019_by_Glenn_Francis_%28cropped%29.jpg"
        case "macan":
            urlString = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Macan-2020.jpg/330px-Macan-2020.jpg"
        default:
            urlString = nil
        }
        return urlString.flatMap(URL.init(string:))
    }

    static let beamSVCFallbackVoices: [VoiceInfo] = [
        VoiceInfo(id: "dionn_v1_singing", name: "Dionn V1 Singing", category: "Default Male", description: "Male singing voice", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "freya_idol", name: "Freya Idol", category: "Default Female", description: "Female idol-style vocal voice", previewUrl: nil, language: ["id"], voiceType: "default"),
        VoiceInfo(id: "taylor_swift_singer", name: "Taylor Swift", category: "Celebrity", description: "Singer-style pop vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "the_weeknd", name: "The Weeknd", category: "Celebrity", description: "The Weeknd-style male pop vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "ariana_grande", name: "Ariana Grande", category: "Celebrity", description: "Ariana Grande-style female pop vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "dua_lipa", name: "Dua Lipa", category: "Celebrity", description: "Dua Lipa-style female pop vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "chris_martin", name: "Chris Martin", category: "Celebrity", description: "Chris Martin / Coldplay-style male rock-pop vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "lil_wayne", name: "Lil Wayne", category: "Celebrity", description: "Lil Wayne-style male rap vocal", previewUrl: nil, language: ["en"], voiceType: "singer"),
        VoiceInfo(id: "drake", name: "Drake", category: "Celebrity", description: "Drake-style male rap vocal", previewUrl: nil, language: ["en"], voiceType: "singer")
    ]
}
