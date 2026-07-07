import Foundation

@MainActor
public final class TTFATelemetry: ObservableObject {
    public static let shared = TTFATelemetry()
    
    // Telemetry Statistics
    private(set) var totalVoiceTaps: Int = 0
    private(set) var cacheHits: Int = 0
    private(set) var preconversionReadyHits: Int = 0
    
    // Track timing starts by track key (or track ID + voice ID)
    private var tapTimes: [String: Date] = [:]
    private var requestTimes: [String: Date] = [:]
    
    private init() {}
    
    private func makeKey(trackTitle: String, voiceId: String) -> String {
        return "\(trackTitle.lowercased())::\(voiceId.lowercased())"
    }
    
    /// User tapped to play/convert a voice
    public func recordVoiceTap(trackTitle: String, voiceId: String) {
        let key = makeKey(trackTitle: trackTitle, voiceId: voiceId)
        tapTimes[key] = Date()
        totalVoiceTaps += 1
        print("📊 [TTFA] tap track=\(trackTitle) voice=\(voiceId) total=\(totalVoiceTaps)")
    }
    
    /// Network request sent to server
    public func recordConversionRequestStart(trackTitle: String, voiceId: String) {
        let key = makeKey(trackTitle: trackTitle, voiceId: voiceId)
        requestTimes[key] = Date()
        print("📊 [TTFA] request_start track=\(trackTitle) voice=\(voiceId)")
    }
    
    /// Network request received from server
    public func recordConversionRequestEnd(trackTitle: String, voiceId: String) {
        let key = makeKey(trackTitle: trackTitle, voiceId: voiceId)
        guard let startTime = requestTimes[key] else {
            print("📊 [Telemetry] Warning: conversion request end recorded without matching start time")
            return
        }
        let elapsed = Date().timeIntervalSince(startTime) * 1000.0
        print("📊 [TTFA] request_ms=\(String(format: "%.1f", elapsed)) track=\(trackTitle) voice=\(voiceId)")
        requestTimes.removeValue(forKey: key)
    }
    
    /// Audio playback started
    public func recordPlaybackStarted(trackTitle: String, voiceId: String) {
        let key = makeKey(trackTitle: trackTitle, voiceId: voiceId)
        guard let tapTime = tapTimes[key] else {
            print("📊 [Telemetry] Warning: playback started recorded without matching tap time")
            return
        }
        let elapsed = Date().timeIntervalSince(tapTime) * 1000.0
        print("📊 [TTFA] tap_to_audio_ms=\(String(format: "%.1f", elapsed)) track=\(trackTitle) voice=\(voiceId)")
        tapTimes.removeValue(forKey: key)
        
        printSummary()
    }
    
    /// Pre-conversion readiness checked
    public func recordPreconversionChecked(trackTitle: String, voiceId: String, isReady: Bool) {
        if isReady {
            preconversionReadyHits += 1
        }
        let rate = totalVoiceTaps > 0 ? (Double(preconversionReadyHits) / Double(totalVoiceTaps)) * 100.0 : 0.0
        print("📊 [TTFA] preconv_ready=\(isReady) rate=\(String(format: "%.1f", rate))% (\(preconversionReadyHits)/\(totalVoiceTaps)) track=\(trackTitle) voice=\(voiceId)")
    }
    
    /// Cache hit/miss checked (either local file or completed conversion list)
    public func recordCacheChecked(trackTitle: String, voiceId: String, isHit: Bool) {
        if isHit {
            cacheHits += 1
        }
        let rate = totalVoiceTaps > 0 ? (Double(cacheHits) / Double(totalVoiceTaps)) * 100.0 : 0.0
        print("📊 [TTFA] cache_hit=\(isHit) rate=\(String(format: "%.1f", rate))% (\(cacheHits)/\(totalVoiceTaps)) track=\(trackTitle) voice=\(voiceId)")
    }
    
    private func printSummary() {
        let cacheRate = totalVoiceTaps > 0 ? (Double(cacheHits) / Double(totalVoiceTaps)) * 100.0 : 0.0
        let preconvRate = totalVoiceTaps > 0 ? (Double(preconversionReadyHits) / Double(totalVoiceTaps)) * 100.0 : 0.0
        print("[TTFA] summary taps=\(totalVoiceTaps) cache_hit_rate=\(String(format: "%.1f", cacheRate))% preconv_ready_rate=\(String(format: "%.1f", preconvRate))%")
    }
}
