//
//  AudioManager.swift
//  BeamApp
//
//  Created by Jihaha kim on 9/22/24.
//

import AVFoundation
import SwiftUI
import Combine
import MusicKit
import MediaPlayer

final class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer
    private var nowPlayingObserver: NSObjectProtocol?
    private var playbackStateObserver: NSObjectProtocol?
    
    private var avPlayer: AVPlayer?
    private var isPlayingAIMusic: Bool = false
    
    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    
    private var timer: Timer?
    private var lastCheckedTime: TimeInterval = 0
    static let audioDidFinishNotification = Notification.Name("AudioDidFinishPlaying")

    private init() {
        setupNotifications()
        startTimer()
        musicPlayerController.repeatMode = .none
    }
    
    private func setupNotifications() {
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayerController,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }

        musicPlayerController.beginGeneratingPlaybackNotifications()
    }
    
    static func fetchPlayableAISongs(with token: String) async throws -> [PlayableTrackDTO] {
            guard let url = URL(string: Endpoints.AISong.playable) else {
                 throw NSError(domain: "InvalidURL", code: 0)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                 let responseBody = String(data: data, encoding: .utf8) ?? ""
                 throw NSError(domain: "Server Error", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: ["responseBody": responseBody])
            }

            return try JSONDecoder().decode([PlayableTrackDTO].self, from: data)
        }

    private func handlePlaybackStateChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.musicPlayerController.playbackState {
            case .stopped:
                self.isPlaying = false
                if self.currentTime >= (self.duration - 1) {
                    NotificationCenter.default.post(
                        name: AudioManager.audioDidFinishNotification,
                        object: nil
                    )
                }
            case .playing:
                self.isPlaying = true
            case .paused:
                self.isPlaying = false
            default:
                break
            }
        }
    }
    
    private func handleNowPlayingItemChange() {
        if let currentItem = musicPlayerController.nowPlayingItem {
            DispatchQueue.main.async { [weak self] in
                self?.currentTrackMetadata = (
                    title: currentItem.title,
                    artist: currentItem.artist,
                    albumArt: currentItem.artwork?.image(at: CGSize(width: 300, height: 300))
                )
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
            self?.checkForTrackCompletion()
        }
    }
    
    private func checkForTrackCompletion() {
        let currentPlaybackTime = musicPlayerController.currentPlaybackTime
        let totalDuration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
        
        if totalDuration > 0 && (totalDuration - currentPlaybackTime) <= 1 {
            NotificationCenter.default.post(
                name: AudioManager.audioDidFinishNotification,
                object: nil
            )
        }
        lastCheckedTime = currentPlaybackTime
    }
    
    private func updatePlaybackTime() {
        if !isPlayingAIMusic {
            currentTime = musicPlayerController.currentPlaybackTime
            duration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
        }
    }
    
    func playAppleMusicTrack(with title: String) async throws {
        do {
            let authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else {
                throw NSError(domain: "com.yourapp.music", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Music 권한이 없습니다. 현재 상태: \(authorizationStatus)"])
            }
            
            let subscriptionStatus = try await MusicSubscription.current
            guard subscriptionStatus.canPlayCatalogContent else {
                throw NSError(domain: "com.yourapp.music", code: 2, userInfo: [NSLocalizedDescriptionKey: "Apple Music 구독이 필요합니다. 현재 구독 상태가 유효하지 않습니다."])
            }
            
            guard !title.isEmpty else {
                throw NSError(domain: "com.yourapp.music", code: 3, userInfo: [NSLocalizedDescriptionKey: "트랙 제목이 비어있습니다."])
            }
            
            var catalogSearchRequest = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
            catalogSearchRequest.limit = 1
            
            let response = try await catalogSearchRequest.response()
            
            guard let song = response.songs.first else {
                throw NSError(domain: "com.yourapp.music", code: 4, userInfo: [NSLocalizedDescriptionKey: "'\(title)' 트랙을 Apple Music에서 찾을 수 없습니다."])
            }
            
            if isPlayingAIMusic {
                avPlayer?.pause()
                isPlayingAIMusic = false
            }
            
            await playMusicWithPlayerController(song: song)
            
        } catch {
            throw error
        }
    }

    @MainActor
    private func playMusicWithPlayerController(song: MusicKit.Song) async {
        let storeID = song.id.rawValue
        if musicPlayerController.nowPlayingItem?.playbackStoreID != storeID {
            musicPlayerController.setQueue(with: [storeID])
            musicPlayerController.play()
            isPlaying = true
            await updateTrackMetadata(song: song)
        }
    }
    
    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) {
        
        self.currentTrackMetadata = (title: song.title, artist: song.artistName, albumArt: nil)

        Task {
            if let artwork = song.artwork {
                if let artworkURL = artwork.url(width: 300, height: 300) {
                    if let (data, _) = try? await URLSession.shared.data(from: artworkURL) {
                        DispatchQueue.main.async {
                            self.currentTrackMetadata.albumArt = UIImage(data: data)
                        }
                    }
                }
            }
        }
    }
    
    func queueNextTrack(trackTitle: String) async {
        let authorizationStatus = await MusicAuthorization.request()
        guard authorizationStatus == .authorized else { return }
        
        do {
            var catalogSearchRequest = MusicCatalogSearchRequest(term: trackTitle, types: [MusicKit.Song.self]) // <- 수정: MusicKit.Song.self 사용
            catalogSearchRequest.limit = 1
            let response = try await catalogSearchRequest.response()
            
            if let nextSong = response.songs.first {
                let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [nextSong.id.rawValue])
                musicPlayerController.prepend(descriptor)
            }
        } catch {
            print("다음 트랙 큐잉 실패: \(error.localizedDescription)")
        }
    }
    
    func playAIMusic(from urlString: String) {
        print("AudioManager: playAIMusic called with URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Invalid URL for AI music: \(urlString)")
            return
        }
        
        if isPlaying {
            pause()
        }
        
        let playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(aiTrackDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        avPlayer?.play()
        isPlayingAIMusic = true
        isPlaying = true
        
        let filename = url.lastPathComponent
        currentTrackMetadata = (
            title: filename.components(separatedBy: ".").first ?? "AI Generated Music",
            artist: "AI Voice",
            albumArt: nil
        )
        
        startAIPlaybackTimer(for: playerItem)
    }
    
    private func startAIPlaybackTimer(for playerItem: AVPlayerItem) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlayingAIMusic else { return }
            
            if let currentItem = self.avPlayer?.currentItem {
                self.currentTime = CMTimeGetSeconds(currentItem.currentTime())
                self.duration = CMTimeGetSeconds(currentItem.duration)
                
                if self.duration > 0 && (self.duration - self.currentTime) <= 1 {
                    NotificationCenter.default.post(
                        name: AudioManager.audioDidFinishNotification,
                        object: nil
                    )
                }
            }
        }
    }
    
    @objc private func aiTrackDidFinish(_ notification: Notification) {
        isPlayingAIMusic = false
        isPlaying = false
        NotificationCenter.default.post(
            name: AudioManager.audioDidFinishNotification,
            object: nil
        )
    }
    
    func pause() {
        if isPlayingAIMusic {
            avPlayer?.pause()
        } else {
            musicPlayerController.pause()
        }
        isPlaying = false
    }
    
    func play() {
        if isPlayingAIMusic {
            avPlayer?.play()
        } else {
            musicPlayerController.play()
        }
        isPlaying = true
    }
    
    func seek(to seconds: Double) {
        if isPlayingAIMusic {
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            avPlayer?.seek(to: time)
        } else {
            musicPlayerController.currentPlaybackTime = seconds
        }
    }
    
    func getCurrentTime() -> Double {
        return currentTime
    }
    
    func getDuration() -> Double {
        return duration
    }
    
    deinit {
        timer?.invalidate()
        musicPlayerController.endGeneratingPlaybackNotifications()
        if let observer = playbackStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = nowPlayingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
}
