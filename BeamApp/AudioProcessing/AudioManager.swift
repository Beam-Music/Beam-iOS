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
        nowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayerController,
            queue: .main
        ) { [weak self] _ in
            self?.handleNowPlayingItemChange()
        }
        musicPlayerController.beginGeneratingPlaybackNotifications()
    }
    
    private func handlePlaybackStateChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.musicPlayerController.playbackState {
            case .stopped:
                self.isPlaying = false
                NotificationCenter.default.post(
                    name: AudioManager.audioDidFinishNotification,
                    object: nil
                )
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
            
            if (currentPlaybackTime < lastCheckedTime) ||
               (totalDuration > 0 && (totalDuration - currentPlaybackTime) <= 1) {
                NotificationCenter.default.post(
                    name: AudioManager.audioDidFinishNotification,
                    object: nil
                )
            }
            lastCheckedTime = currentPlaybackTime
        }
    
    private func updatePlaybackTime() {
        currentTime = musicPlayerController.currentPlaybackTime
        duration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
    }
    
    func playAppleMusicTrack(with trackTitle: String) async {
        let authorizationStatus = await MusicAuthorization.request()
        guard authorizationStatus == .authorized else {
            print("Apple Music 권한이 필요합니다.")
            return
        }
        
        do {
            let subscriptionStatus = try await MusicSubscription.current
            guard subscriptionStatus.canPlayCatalogContent else {
                print("Apple Music 구독이 필요합니다.")
                return
            }
            
            let catalogSearchRequest = MusicCatalogSearchRequest(term: trackTitle, types: [Song.self])
            let response = try await catalogSearchRequest.response()
            
            guard let song = response.songs.first else {
                print("해당 트랙을 찾을 수 없습니다.")
                return
            }
            
            await playMusicWithPlayerController(song: song)
        } catch {
            print("Apple Music 트랙 재생 중 오류 발생: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func playMusicWithPlayerController(song: Song) async {
        musicPlayerController.setQueue(with: [song.id.rawValue])
        musicPlayerController.play()
        isPlaying = true
        await updateTrackMetadata(song: song)
    }
    
    @MainActor
    private func updateTrackMetadata(song: Song) {
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
            let catalogSearchRequest = MusicCatalogSearchRequest(term: trackTitle, types: [Song.self])
            let response = try await catalogSearchRequest.response()
            if let nextSong = response.songs.first {
                let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: [nextSong.id.rawValue])
                musicPlayerController.append(descriptor)
            }
        } catch {
            print("Failed to queue next track: \(error)")
        }
    }
    
    func pause() {
        musicPlayerController.pause()
        isPlaying = false
    }
    
    func play() {
        musicPlayerController.play()
        isPlaying = true
    }
    
    func seek(to seconds: Double) {
        musicPlayerController.currentPlaybackTime = seconds
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
    }
}
