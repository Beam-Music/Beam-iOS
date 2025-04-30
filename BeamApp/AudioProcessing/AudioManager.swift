import AVFoundation
import SwiftUI
import Combine
import MusicKit
import MediaPlayer

enum PlayerError: Error, LocalizedError {
    case musicAuthorizationFailed
    case noMusicSubscription
    case invalidTrackTitle
    case trackNotFound(String)
    case invalidURL(String)
    case networkError(Error)
    case decodingError(Error)
    case unknownError(Error)
    case playbackError(String)
    
    var errorDescription: String? {
        switch self {
        case .musicAuthorizationFailed: return "Apple Music 접근 권한이 필요합니다."
        case .noMusicSubscription: return "Apple Music 구독이 필요합니다."
        case .invalidTrackTitle: return "유효하지 않은 곡 제목입니다."
        case .trackNotFound(let title): return "'\(title)' 곡을 찾을 수 없습니다."
        case .invalidURL(let url): return "잘못된 URL입니다: \(url)"
        case .networkError(let error): return "네트워크 오류: \(error.localizedDescription)"
        case .decodingError(let error): return "데이터 처리 오류: \(error.localizedDescription)"
        case .unknownError(let error): return "알 수 없는 오류: \(error.localizedDescription)"
        case .playbackError(let message): return "재생 오류: \(message)"
        }
    }
}

@MainActor
final class AudioManager: ObservableObject, AudioManagerProtocol {
    static let shared = AudioManager()
    
    let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer
    private var avPlayer: AVPlayer?
    private var avPlayerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var playbackStateObserver: NSObjectProtocol?
    private var avPlayerItemObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    
    private var isPlayingAIMusic: Bool = false
    var isAIPlaying: Bool {
        return self.isPlayingAIMusic
    }
    
    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlayingMusic: Bool = false
    
    private var timer: Timer?
    static let audioDidFinishNotification = Notification.Name("AudioDidFinish")
    
    private init() {
        setupAudioSession()
        setupNotifications()
        startTimerForMusicKit()
        musicPlayerController.repeatMode = .none
        handlePlaybackStateChange()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioManager: AVAudioSession configured.")
        } catch {
            print("AudioManager Error: Failed setting audio session category: \(error)")
        }
    }
    
    private func setupNotifications() {
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayerController,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }
        musicPlayerController.beginGeneratingPlaybackNotifications()
    }
    
    private func handlePlaybackStateChange() {
        let currentState = musicPlayerController.playbackState
        let isNowPlaying = (currentState == .playing)
        
        if isPlayingMusic != isNowPlaying {
            isPlayingMusic = isNowPlaying
        }
        
        if let item = musicPlayerController.nowPlayingItem {
            currentTrackMetadata = (
                title: item.title,
                artist: item.artist,
                albumArt: item.artwork?.image(at: CGSize(width: 300, height: 300))
            )
        }
    }
    
    func play() async {
        if !isPlayingMusic {
            if isPlayingAIMusic {
                avPlayer?.play()
                print("AudioManager: Resuming AI playback.")
            } else {
                if avPlayer != nil {
                    print("AudioManager: Cleaning up AI playback before starting MusicKit.")
                    cleanupAIPlayback()
                }
                print("AudioManager: Playing MusicKit.")
                musicPlayerController.play()
            }
            isPlayingMusic = true
        }
    }
    
    func tryResume() async -> Bool {
        if !isPlayingMusic {
            if isPlayingAIMusic {
                if let player = avPlayer, player.rate == 0 {
                    print("AudioManager: Resuming paused AI track")
                    player.play()
                    isPlayingMusic = true
                    return true
                }
            } else {
                if musicPlayerController.playbackState == .paused {
                    print("AudioManager: Resuming paused MusicKit track")
                    musicPlayerController.play()
                    isPlayingMusic = true
                    return true
                }
            }
        }
        print("AudioManager: tryResume failed - already playing or cannot resume")
        return false
    }
    
    func pause() async {
        if isPlayingMusic {
            if isPlayingAIMusic {
                print("AudioManager: Pausing AI playback")
                avPlayer?.pause()
            } else {
                print("AudioManager: Pausing MusicKit playback")
                musicPlayerController.pause()
            }
            isPlayingMusic = false
        }
    }
    
    func stop() async {
        print("AudioManager: stop() called.")
        if isPlayingAIMusic {
            cleanupAIPlayback()
        } else {
            musicPlayerController.stop()
        }
        currentTime = 0
        duration = 0
        isPlayingMusic = false
        isPlayingAIMusic = false
        currentTrackMetadata = (nil, nil, nil)
    }
    
    func reset() async {
        print("AudioManager: reset() called.")
        await stop()
        avPlayer = nil
        removeAVPlayerObservers()
        removePeriodicTimeObserver()
    }
    
    func isPlaying() async -> Bool {
        return self.isPlayingMusic
    }
    
    func playAppleMusicTrack(title: String?, storeID: String?) async throws {
        print("🎵 AudioManager: Attempting to play Apple Music track")
        print("   Title: \(title ?? "nil")")
        print("   Store ID: \(storeID ?? "nil - will search by title")")
        
        // Stop any existing playback
        await stop()
        
        do {
            if let storeID = storeID {
                // Try to play using store ID
                print("🎵 Playing with store ID: \(storeID)")
                musicPlayerController.setQueue(with: [storeID])
                musicPlayerController.play()
            } else if let title = title {
                // Search and play by title
                print("🎵 Searching for track: \(title)")
                let request = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
                let response = try await request.response()
                
                if let song = response.songs.first {
                    print("🎵 Found track: \(song.title)")
                    musicPlayerController.setQueue(with: [song.id.rawValue])
                    musicPlayerController.play()
                } else {
                    print("⚠️ No matching track found")
                    throw PlayerError.trackNotFound(title)
                }
            } else {
                print("⚠️ No title or store ID provided")
                throw PlayerError.invalidTrackTitle
            }
            
            // Start playback
            musicPlayerController.play()
            isPlayingMusic = true
            isPlayingAIMusic = false
            print("✅ Playback started successfully")
        } catch {
            print("❌ Failed to start playback: \(error)")
            isPlayingMusic = false
            isPlayingAIMusic = false
            throw error
        }
    }
    
    func playAIMusic(from urlString: String, title: String, artist: String) async throws {
        print("🎵 Starting AI music playback with file URL: \(urlString)")
        print("   Title: \(title)")
        print("   Artist: \(artist)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid AI music URL: \(urlString)")
            throw PlayerError.invalidURL(urlString)
        }
        
        // Stop any existing playback
        await stop()
        
        // Create a new player item
        let playerItem = AVPlayerItem(url: url)
        avPlayerItem = playerItem
        
        // Add observers for player item status and duration
        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
                print("✅ AVPlayerItem is ready to play")
                self.duration = item.duration.seconds
                // Update metadata when item is ready
                self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
            case .failed:
                print("❌ AVPlayerItem failed to load: \(item.error?.localizedDescription ?? "Unknown error")")
            case .unknown:
                print("⚠️ AVPlayerItem status is unknown")
            @unknown default:
                break
            }
        }
        
        durationObserver = playerItem.observe(\.duration) { [weak self] item, _ in
            guard let self = self else { return }
            if item.duration.isValid {
                self.duration = item.duration.seconds
                print("📊 Updated AI track duration: \(self.duration) seconds")
            }
        }
        
        // Create and configure the player
        avPlayer = AVPlayer(playerItem: playerItem)
        
        // Add time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
        }
        
        // Add observer for playback completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Wait for player item to be ready
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        guard playerItem.status == .readyToPlay else {
            print("❌ AVPlayerItem is not ready to play")
            throw PlayerError.playbackError("AI music playback failed to start - item not ready")
        }
        
        // Start playback
        avPlayer?.play()
        isPlayingMusic = true
        isPlayingAIMusic = true
        
        // Update metadata
        currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
        
        // Verify playback started
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        guard await isPlaying() else {
            print("❌ AI music playback failed to start")
            throw PlayerError.playbackError("AI music playback failed to start")
        }
        
        print("✅ AI music playback started successfully")
    }
    
    private func updateAITrackMetadata(title: String, artist: String) async {
        self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
        
        // Now Playing Center 업데이트
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        
        if let player = avPlayer {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.duration.seconds ?? 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func cleanupAIPlayback() {
        print("AudioManager: Cleaning up AI playback")
        avPlayer?.pause()
        avPlayer = nil
        avPlayerItem = nil
        removeAVPlayerObservers()
        removePeriodicTimeObserver()
        durationObserver?.invalidate()
        durationObserver = nil
        isPlayingAIMusic = false
        currentTime = 0
        duration = 0
    }
    
    private func removeAVPlayerObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        
        if let observer = avPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            avPlayerItemObserver = nil
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    func seek(to seconds: Double) async {
        let targetTime = max(0, seconds)
        print("AudioManager: Seeking to \(targetTime)")
        
        if isPlayingAIMusic {
            guard let player = avPlayer, let item = player.currentItem, item.status == .readyToPlay else {
                print("AudioManager Seek Error: AVPlayer not ready.")
                return
            }
            let time = CMTime(seconds: targetTime, preferredTimescale: 600)
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            self.currentTime = targetTime
        } else {
            if let itemDuration = musicPlayerController.nowPlayingItem?.playbackDuration, itemDuration > 0 {
                let boundedTime = min(targetTime, itemDuration)
                musicPlayerController.currentPlaybackTime = boundedTime
                self.currentTime = boundedTime
            }
        }
    }
    
    private func startTimerForMusicKit() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPlayingAIMusic else { return }
            self.updateMusicKitPlaybackProgress()
        }
    }
    
    private func updateMusicKitPlaybackProgress() {
        guard !isPlayingAIMusic else { return }
        
        let currentState = musicPlayerController.playbackState
        let isNowPlaying = (currentState == .playing)
        
        if isPlayingMusic != isNowPlaying {
            isPlayingMusic = isNowPlaying
        }
        
        if isNowPlaying {
            let newTime = musicPlayerController.currentPlaybackTime
            if newTime.isFinite && newTime >= 0 {
                if abs(currentTime - newTime) > 0.1 { currentTime = newTime }
            }
            let newDuration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
            if newDuration.isFinite && newDuration > 0 {
                if duration != newDuration { duration = newDuration }
            } else if duration != 0 {
                duration = 0
            }
            checkForAppleMusicTrackCompletion()
        }
    }
    
    private func checkForAppleMusicTrackCompletion() {
        guard !isPlayingAIMusic, isPlayingMusic else { return }
        
        if duration > 0 && (currentTime >= duration - 0.5 || currentTime > duration + 0.1) {
            print("AudioManager: MusicKit track completion detected by timer.")
            NotificationCenter.default.post(
                name: AudioManager.audioDidFinishNotification,
                object: nil
            )
        }
    }
    
    private func handlePlaybackError(_ error: Error) async {
        print("AudioManager Error Handler: \(error.localizedDescription)")
        isPlayingMusic = false
        
        if isPlayingAIMusic {
            cleanupAIPlayback()
        } else {
            musicPlayerController.stop()
        }
    }
    
    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) async {
        print("AudioManager: Updating metadata from fetched MusicKit.Song: \(song.title)")
        self.currentTrackMetadata = (title: song.title, artist: song.artistName, albumArt: nil)

        Task.detached {
            var image: UIImage? = nil
            if let artwork = song.artwork, let url = artwork.url(width: 300, height: 300) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    image = UIImage(data: data)
                } catch {
                    print("AudioManager Error: Failed loading artwork for \(song.title): \(error)")
                }
            }
            await MainActor.run {
                if self.currentTrackMetadata.title == song.title {
                    self.currentTrackMetadata.albumArt = image
                } else {
                    print("AudioManager: Track changed before artwork loaded for \(song.title).")
                }
            }
        }
    }

    func cleanup() {
        print("AudioManager: cleanup() called.")
        timer?.invalidate()
        timer = nil
        musicPlayerController.endGeneratingPlaybackNotifications()
        if let observer = playbackStateObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackStateObserver = nil
        }
        removeAVPlayerObservers()
        removePeriodicTimeObserver()

        if avPlayer != nil {
            avPlayer?.pause()
            avPlayer?.replaceCurrentItem(with: nil)
            avPlayer = nil
        }
        if musicPlayerController.playbackState != .stopped {
            musicPlayerController.stop()
        }
        print("AudioManager: Cleanup finished.")
    }

    deinit {
        print("AudioManager: deinit called.")
    }

    @objc private func playerItemDidReachEnd() {
        print("AudioManager: AI music playback finished")
        isPlayingMusic = false
        isPlayingAIMusic = false
        currentTime = 0
        
        // Clean up the player
        cleanupAIPlayback()
        
        // Notify that playback has finished
        NotificationCenter.default.post(
            name: AudioManager.audioDidFinishNotification,
            object: nil
        )
    }
}
