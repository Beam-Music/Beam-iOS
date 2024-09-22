//
//  AudioManager.swift
//  BeamApp
//
//  Created by Jihaha kim on 9/22/24.
//

import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private var player: AVPlayer?
    private var session = AVAudioSession.sharedInstance()

    private init() {}

    private func activateSession() {
        do {
            try session.setCategory(.playback, mode: .default, options: [])
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

