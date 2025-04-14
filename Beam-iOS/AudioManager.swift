// Add these methods to your AudioManager

func playAISong(with url: URL) {
    // Stop any currently playing music
    if isPlaying {
        stopPlayback()
    }
    
    // Create a new AVPlayer with the provided URL
    let playerItem = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: playerItem)
    
    // Set up audio session for playback
    try? AVAudioSession.sharedInstance().setCategory(.playback)
    try? AVAudioSession.sharedInstance().setActive(true)
    
    // Play the audio
    player?.play()
    isPlaying = true
    
    // Set up notification for when the song ends
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(playerDidFinishPlaying),
        name: .AVPlayerItemDidPlayToEndTime,
        object: playerItem
    )
}

// Function to handle AI song playback from string URL
func playAISong(withURLString urlString: String) {
    guard let url = URL(string: urlString) else {
        print("Invalid URL for AI Song")
        return
    }
    playAISong(with: url)
}
