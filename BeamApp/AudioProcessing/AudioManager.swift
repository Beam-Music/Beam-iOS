//
//  AudioManager.swift
//  BeamApp
//
//  Created by Jihaha kim on 9/22/24.
//

import AVFoundation

final class AudioManager {
    static let shared = AudioManager() // 싱글톤 객체

    private var player: AVPlayer?
    private var session = AVAudioSession.sharedInstance()

    private init() {}

    // AVAudioSession 설정
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

    // 오디오 재생 시작
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

    // 일시정지
    func pause() {
        player?.pause()
    }

    // 재개
    func play() {
        player?.play()
    }

    // 세션 비활성화 (필요할 때 호출)
    func deactivateSession() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // 플레이어로부터 재생 시간 가져오기
    func getPlaybackDuration() -> Double {
        return player?.currentItem?.duration.seconds ?? 0
    }
}

