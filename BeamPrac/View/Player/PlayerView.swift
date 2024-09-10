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
        isPlaying.toggle()
    }
    
    private func nextTrack() {
        currentTrack = "Next Track"
        // 여기에 다음 트랙으로 이동하는 로직을 구현하세요
    }
    
    private func previousTrack() {
        currentTrack = "Previous Track"
        // 여기에 이전 트랙으로 이동하는 로직을 구현하세요
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView()
    }
}
