//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct PlayerView: View {
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    
    @ObservedObject private var audioManager = AudioManager.shared
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Player View")
                .font(.largeTitle)
            
            if let albumArt = audioManager.currentTrackMetadata.albumArt {
                Image(uiImage: albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
            }
            
            Text(audioManager.currentTrackMetadata.title ?? "No Track")
                .font(.headline)
            
            Text(audioManager.currentTrackMetadata.artist ?? "Unknown Artist")
                .font(.subheadline)
                .foregroundColor(.gray)
            
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
            
            HStack {
                Text(formatTime(currentTime))
                Spacer()
                Text(formatTime(duration))
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
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func playPause() {
        if isPlaying {
            AudioManager.shared.pause()
        } else {
            AudioManager.shared.play()
        }
        isPlaying.toggle()
    }
    
    private func nextTrack() {
        AudioManager.shared.startAudio()
    }
    
    private func previousTrack() {
        AudioManager.shared.startAudio()
    }
}

//struct PlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayerView()
//    }
//}
