//
//  AudioManager.swift
//  BeamApp
//
//  Created by Jihaha kim on 9/22/24.
//

import AVFoundation
import SwiftUI
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()
    private var player: AVPlayer?
    private var session = AVAudioSession.sharedInstance()

    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    private func activateSession() {
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .defaultToSpeaker]
            )
        } catch {
            print("Failed to set audio session category: \(error.localizedDescription)")
        }
        
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
        
        do {
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("Failed to override audio port: \(error.localizedDescription)")
        }
    }

    // url 에서도 metadata 가져오기
    private func extractMetadata(from asset: AVAsset) {
        Task {
            do {
                let metadata = try await asset.load(.commonMetadata)
                await processMetadata(metadata)
            } catch {
                print("Failed to load metadata: \(error)")
            }
        }
    }
    
    private func processMetadata(_ metadata: [AVMetadataItem]) async {
        for item in metadata {
            guard let commonKey = item.commonKey else { continue }
            
            switch commonKey {
            case .commonKeyTitle:
                if let title = try? await item.load(.stringValue) {
                    await updateTrackMetadata(title: title)
                }
            case .commonKeyArtist:
                if let artist = try? await item.load(.stringValue) {
                    await updateTrackMetadata(artist: artist)
                }
            case .commonKeyArtwork:
                if let data = try? await item.load(.dataValue),
                   let image = UIImage(data: data) {
                    await updateTrackMetadata(albumArt: image)
                }
            default:
                break
            }
        }
    }
    
    @MainActor
    private func updateTrackMetadata(title: String? = nil, artist: String? = nil, albumArt: UIImage? = nil) {
        if let title = title {
            currentTrackMetadata.title = title
        }
        if let artist = artist {
            currentTrackMetadata.artist = artist
        }
        if let albumArt = albumArt {
            currentTrackMetadata.albumArt = albumArt
        }
    }

    func startAudio() {
        activateSession()

        // URL을 필요에 맞게 수정
        let url = URL(string: "https://www.learningcontainer.com/wp-content/uploads/2020/02/Kalimba.mp3")!
        let playerItem = AVPlayerItem(url: url)
        
        if let player = player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            player = AVPlayer(playerItem: playerItem)
        }
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func play() {
        player?.play()
    }

    func deactivateSession() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    func getPlaybackDuration() -> Double {
        return player?.currentItem?.duration.seconds ?? 0
    }
    
    func getCurrentTime() -> Double {
        return player?.currentTime().seconds ?? 0
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: time)
    }
    
    func getDuration() -> Double {
        return player?.currentItem?.duration.seconds ?? 0
    }
}

