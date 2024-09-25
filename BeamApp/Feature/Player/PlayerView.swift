//
//  PlayerView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct PlayerView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    
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
            
            if audioManager.duration > 0 {
                Slider(value: $audioManager.currentTime, in: 0...audioManager.duration, onEditingChanged: { editing in
                    if !editing {
                        audioManager.seek(to: audioManager.currentTime)
                    }
                })
            } else {
                Slider(value: .constant(0), in: 0...1)
                    .disabled(true)
            }
            
            HStack {
                Text(formatTime(audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            
            HStack(spacing: 30) {
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: playPause) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
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
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "00:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func playPause() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
    
    private func nextTrack() {
        Task {
            await audioManager.playAppleMusicTrack(with: "fix you")
        }
    }
    
    private func previousTrack() {
        Task {
            await audioManager.playAppleMusicTrack(with: "Shake It Off")
        }
    }
}

//struct PlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayerView()
//    }
//}
