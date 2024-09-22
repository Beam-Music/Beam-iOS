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
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Player View")
                .font(.largeTitle)
            
            Text("Now Playing: \(currentTrack)")
                .font(.headline)
            
            if duration > 0 {
                Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
                    if !editing {
                        AudioManager.shared.seek(to: currentTime)
                    }
                })
            } else {
                Slider(value: .constant(0), in: 0...1)
                    .disabled(true)
            }
            
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
        .onReceive(timer) { _ in
            currentTime = AudioManager.shared.getCurrentTime()
            duration = AudioManager.shared.getDuration()
        }
    }
    
    private func playPause() {
        if isPlaying {
            AudioManager.shared.pause()
        } else {
            if currentTrack == "No track selected" {
                currentTrack = "Track 1"
                AudioManager.shared.startAudio()
            } else {
                AudioManager.shared.play()
            }
        }
        isPlaying.toggle()
    }
    
    private func nextTrack() {
        currentTrack = "Next Track"
        AudioManager.shared.startAudio()
    }
    
    private func previousTrack() {
        currentTrack = "Previous Track"
        AudioManager.shared.startAudio()
    }
}


//struct PlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayerView()
//    }
//}
