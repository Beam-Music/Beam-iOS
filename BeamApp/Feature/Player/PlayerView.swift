//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct PlayerView: View {
    @State private var isPlaying = false
    @State private var currentTrack = "No track selected"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Player View")
                .font(.largeTitle)
            
            Text("Now Playing: \(currentTrack)")
                .font(.headline)
            
            HStack(spacing: 30) {
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: playPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                
                Button(action: nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
    }
    
    private func playPause() {
        if isPlaying {
            AudioManager.shared.pause()
        } else {
            if currentTrack == "No track selected" {
                // 첫 트랙을 시작할 때 기본 트랙 설정
                currentTrack = "Track 1"
                AudioManager.shared.startAudio() // 첫 번째 트랙 재생
            } else {
                AudioManager.shared.play() // 현재 트랙 재생
            }
        }
        isPlaying.toggle()
    }
    
    private func nextTrack() {
        currentTrack = "Next Track"
        // 다음 트랙 로직 구현
        // 예시로 다음 트랙 URL 변경 후 재생
        AudioManager.shared.startAudio() // 다음 트랙으로 재생
    }
    
    private func previousTrack() {
        currentTrack = "Previous Track"
        // 이전 트랙 로직 구현
        AudioManager.shared.startAudio() // 이전 트랙으로 재생
    }
}


//struct PlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayerView()
//    }
//}
