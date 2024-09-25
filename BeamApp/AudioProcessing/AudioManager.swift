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

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer
    
    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying: Bool = false

    private var timeObserver: Any?

    private init() {
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
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

            print("검색된 트랙 목록:")
            for (index, song) in response.songs.enumerated() {
                print("트랙 \(index + 1): \(song.title) - \(song.artistName) (ID: \(song.id))")
            }

            guard let song = response.songs.first else {
                print("해당 트랙을 찾을 수 없습니다.")
                return
            }
            playMusicWithPlayerController(songID: song.id)

            await updateTrackMetadata(song: song)
        } catch {
            print("Apple Music 트랙 재생 중 오류 발생: \(error.localizedDescription)")
        }
    }

    private func playMusicWithPlayerController(songID: MusicItemID) {
        musicPlayerController.setQueue(with: [songID.rawValue])
        musicPlayerController.play()
        isPlaying = true
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

    func pause() {
        musicPlayerController.pause()
        isPlaying = false
    }

    func play() {
        musicPlayerController.play()
        isPlaying = true
    }

    func seek(to seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: targetTime)
    }

    func getCurrentTime() -> Double {
        return currentTime
    }

    func getDuration() -> Double {
        return duration
    }
}
