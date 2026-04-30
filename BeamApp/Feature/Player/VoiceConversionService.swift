//
//  VoiceConversionService.swift
//  BeamApp
//
//  Created by freed on 9/10/24.
//

import Foundation
import AVFoundation

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

class VoiceConversionService {
    
    func performLalalAIVoiceChange(
        audioData: Data,
        voiceId: String
    ) async throws -> Data {
        let client = LalalAIClient(apiKey: APIKeys.lalalAI)

        do {
            print("🎤 Using LALAL.AI Voice Change API...")
            print("   Voice ID: \(voiceId)")
            print("   File size: \(audioData.count) bytes")
            
            // 0단계: 크레딧 확인
            print("💳 Step 0: Checking LALAL.AI credits...")
            let credits = try await client.checkCredits()
            
            print("💰 Credit Status:")
            print("   Total: \(credits.total) minutes")
            print("   Used: \(credits.used) minutes")
            print("   Remaining: \(credits.remaining) minutes")
            
            // 파일 크기 확인 (업로드 전에)
            let estimatedDuration = Double(audioData.count) / 16000.0 // 대략적인 초 단위 계산
            let requiredMinutes = estimatedDuration / 60.0
            
            print("📊 Estimated requirements:")
            print("   File duration: \(estimatedDuration) seconds")
            print("   Required credits: \(requiredMinutes) minutes")
            
            if credits.remaining < requiredMinutes {
                print("⚠️ Insufficient credits detected!")
                print("   Need: \(String(format: "%.2f", requiredMinutes)) minutes")
                print("   Have: \(String(format: "%.2f", credits.remaining)) minutes")
                
                // 크레딧이 부족하면 더 짧은 오디오로 자동 조정
                let maxAllowedDuration = credits.remaining * 60.0 // 초 단위로 변환
                let maxAllowedSeconds = min(maxAllowedDuration, 30.0) // 최대 30초로 제한
                
                print("🔄 Auto-adjusting audio duration to \(String(format: "%.1f", maxAllowedSeconds)) seconds")
                
                // 오디오를 더 짧게 자르기
                let trimmedAudioData = try await trimAudioToDuration(audioData, duration: maxAllowedSeconds)
                
                print("✅ Audio trimmed successfully for credit optimization")
                print("   New size: \(trimmedAudioData.count) bytes")
                
                // 자른 오디오로 다시 시도 (재귀 방지를 위해 새로운 함수 호출)
                return try await performLalalAIVoiceChangeWithTrimmedAudio(
                    audioData: trimmedAudioData,
                    voiceId: voiceId
                )
            }
            
            // 1단계: 오디오 파일 업로드
            print("📤 Step 1: Uploading audio file to LALAL.AI...")
            let filename = "audio_\(Int(Date().timeIntervalSince1970)).mp3"
            let uploadResponse = try await client.uploadFile(audioData: audioData, filename: filename)
            
            guard let fileId = uploadResponse.id else {
                throw VoiceConversionError.serverError("Failed to get file ID from upload")
            }
            
            print("✅ File uploaded successfully")
            print("   File ID: \(fileId)")
            print("   File size: \(uploadResponse.size ?? 0) bytes")
            print("   Duration: \(uploadResponse.duration ?? 0) seconds")
            
            // 2단계: 음성 변환 요청
            print("🎵 Step 2: Requesting voice change...")
            
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
            
            print("✅ Voice change requested successfully")
            print("   Task ID: \(taskId)")
            print("   Target voice: \(lalalAIVoice)")
            
            // 3단계: 작업 완료 대기
            print("⏳ Step 3: Waiting for voice change completion...")
            let fileResult = try await client.waitForTaskCompletion(fileId: fileId, maxWaitTime: 300)
            
            print("✅ Voice change completed successfully")
            
            // 4단계: 변환된 오디오 다운로드
            print("📥 Step 4: Downloading converted audio...")
            
            // archive 또는 split 결과에서 다운로드 URL 찾기
            let downloadUrl: String
            let fileSize: Int
            
            if let archive = fileResult.archive, let stemTrack = archive.stem_track, !stemTrack.isEmpty {
                downloadUrl = stemTrack
                fileSize = archive.stem_track_size ?? 0
                print("📥 Using archive result for download")
            } else if let split = fileResult.split, !split.back_track.isEmpty {
                // 음성 변환에서는 back_track이 변환된 음성 파일
                downloadUrl = split.back_track
                fileSize = split.back_track_size
                print("📥 Using split result (back_track) for download")
            } else {
                throw VoiceConversionError.serverError("No download URL available in result")
            }
            
            // 변환된 음성 다운로드
            let convertedAudioData = try await client.downloadAudioFile(from: downloadUrl)
            
            print("✅ Audio downloaded successfully")
            print("   Downloaded size: \(convertedAudioData.count) bytes")
            print("   Original size: \(fileSize) bytes")
            
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
            print("🎤 Using LALAL.AI Voice Change API with trimmed audio...")
            print("   Voice ID: \(voiceId)")
            print("   File size: \(audioData.count) bytes")
            
            // 1단계: 오디오 파일 업로드
            print("📤 Step 1: Uploading trimmed audio file to LALAL.AI...")
            let filename = "trimmed_audio_\(Int(Date().timeIntervalSince1970)).mp3"
            let uploadResponse = try await client.uploadFile(audioData: audioData, filename: filename)
            
            guard let fileId = uploadResponse.id else {
                throw VoiceConversionError.serverError("Failed to get file ID from upload")
            }
            
            print("✅ Trimmed file uploaded successfully")
            print("   File ID: \(fileId)")
            print("   File size: \(uploadResponse.size ?? 0) bytes")
            print("   Duration: \(uploadResponse.duration ?? 0) seconds")
            
            // 2단계: 음성 변환 요청
            print("🎵 Step 2: Requesting voice change for trimmed audio...")
            
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
            
            print("✅ Voice change requested successfully for trimmed audio")
            print("   Task ID: \(taskId)")
            print("   Target voice: \(lalalAIVoice)")
            
            // 3단계: 작업 완료 대기
            print("⏳ Step 3: Waiting for voice change completion...")
            let fileResult = try await client.waitForTaskCompletion(fileId: fileId, maxWaitTime: 300)
            
            print("✅ Voice change completed successfully for trimmed audio")
            
            // 4단계: 변환된 오디오 다운로드
            print("📥 Step 4: Downloading converted audio...")
            
            // archive 또는 split 결과에서 다운로드 URL 찾기
            let downloadUrl: String
            let fileSize: Int
            
            if let archive = fileResult.archive, let stemTrack = archive.stem_track, !stemTrack.isEmpty {
                downloadUrl = stemTrack
                fileSize = archive.stem_track_size ?? 0
                print("📥 Using archive result for download")
            } else if let split = fileResult.split, !split.back_track.isEmpty {
                // 음성 변환에서는 back_track이 변환된 음성 파일
                downloadUrl = split.back_track
                fileSize = split.back_track_size
                print("📥 Using split result (back_track) for download")
            } else {
                throw VoiceConversionError.serverError("No download URL available in result")
            }
            
            // 변환된 음성 다운로드
            let convertedAudioData = try await client.downloadAudioFile(from: downloadUrl)
            
            print("✅ Audio downloaded successfully")
            print("   Downloaded size: \(convertedAudioData.count) bytes")
            print("   Original size: \(fileSize) bytes")
            
            return convertedAudioData
            
        } catch {
            print("❌ LALAL.AI Voice Change error for trimmed audio: \(error)")
            throw error
        }
    }
    
    private func getLalalAIVoiceId(singerVoiceId: String) -> String {
        print("🎤 Getting LALAL.AI voice ID for singer: \(singerVoiceId)")
        
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