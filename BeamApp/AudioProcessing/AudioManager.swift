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
    
    // Current audio URL for AI music playback
    var currentAudioURL: URL? {
        if isPlayingAIMusic, let player = avPlayer, let currentItem = player.currentItem {
            if let urlAsset = currentItem.asset as? AVURLAsset {
                return urlAsset.url
            }
        }
        return nil
    }
    
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
        let audioSession = AVAudioSession.sharedInstance()
        
        // Try multiple approaches to setup audio session
        var sessionSetup = false
        
        // Approach 1: Standard setup
        if !sessionSetup {
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                sessionSetup = true
                print("✅ AudioManager: Audio session setup successful with standard approach")
            } catch {
                print("⚠️ AudioManager: Standard audio session setup failed: \(error)")
            }
        }
        
        // Approach 2: Try without options
        if !sessionSetup {
            do {
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                sessionSetup = true
                print("✅ AudioManager: Audio session setup successful without options")
            } catch {
                print("⚠️ AudioManager: Audio session setup without options failed: \(error)")
            }
        }
        
        // Approach 3: Try with different mode
        if !sessionSetup {
            do {
                try audioSession.setCategory(.playback, mode: .moviePlayback)
                try audioSession.setActive(true)
                sessionSetup = true
                print("✅ AudioManager: Audio session setup successful with moviePlayback mode")
            } catch {
                print("⚠️ AudioManager: Audio session setup with moviePlayback failed: \(error)")
            }
        }
        
        // Approach 4: Minimal setup
        if !sessionSetup {
            do {
                try audioSession.setActive(true)
                sessionSetup = true
                print("✅ AudioManager: Audio session setup successful with minimal setup")
            } catch {
                print("❌ AudioManager: All audio session setup attempts failed: \(error)")
            }
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
            } else {
                if avPlayer != nil {
                    cleanupAIPlayback()
                }
                musicPlayerController.play()
            }
            isPlayingMusic = true
        }
    }
    
    func tryResume() async -> Bool {
        if !isPlayingMusic {
            if isPlayingAIMusic {
                if let player = avPlayer, player.rate == 0 {
                    player.play()
                    isPlayingMusic = true
                    return true
                }
            } else {
                if musicPlayerController.playbackState == .paused {
                    musicPlayerController.play()
                    isPlayingMusic = true
                    return true
                }
            }
        }
        return false
    }
    
    func pause() async {
        if isPlayingMusic {
            if isPlayingAIMusic {
                avPlayer?.pause()
            } else {
                musicPlayerController.pause()
            }
            isPlayingMusic = false
        }
    }
    
    func stop() async {
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
        await stop()
        avPlayer = nil
        removeAVPlayerObservers()
        removePeriodicTimeObserver()
    }
    
    func isPlaying() async -> Bool {
        return self.isPlayingMusic
    }
    
    func playAppleMusicTrack(title: String?, storeID: String?) async throws {
        try await stop()
        
        do {
            // Ensure audio session is active with proper error handling
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
            } catch {
                print("⚠️ AudioManager: Audio session activation failed for Apple Music, trying alternative approach: \(error)")
                try audioSession.setActive(true, options: [])
            }
            
            if let storeID = storeID {
                musicPlayerController.setQueue(with: [storeID])
                try await musicPlayerController.prepareToPlay()
                try await musicPlayerController.play()
            } else if let title = title {
                let request = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
                let response = try await request.response()
                
                if let song = response.songs.first {
                    musicPlayerController.setQueue(with: [song.id.rawValue])
                    try await musicPlayerController.prepareToPlay()
                    try await musicPlayerController.play()
                } else {
                    throw PlayerError.trackNotFound(title)
                }
            } else {
                throw PlayerError.invalidTrackTitle
            }
            
            musicPlayerController.play()
            isPlayingMusic = true
            isPlayingAIMusic = false
        } catch {
            isPlayingMusic = false
            isPlayingAIMusic = false
            print("AudioManager Error: Failed to play Apple Music track: \(error)")
            throw error
        }
    }
    
    func playAIMusic(from urlString: String, title: String, artist: String) async throws {
        try await stop()
        
        let url: URL
        if urlString.hasPrefix("file://") {
            // 이미 완전한 URL인 경우
            guard let fullURL = URL(string: urlString) else {
                throw PlayerError.invalidURL(urlString)
            }
            url = fullURL
        } else if urlString.hasPrefix("/") {
            // 파일 경로인 경우
            url = URL(fileURLWithPath: urlString)
        } else {
            // 일반 URL인 경우
            guard let fullURL = URL(string: urlString) else {
                throw PlayerError.invalidURL(urlString)
            }
            url = fullURL
        }
        
        do {
            print("🎵 AudioManager: Starting AI music playback")
            print("   URL: \(url)")
            print("   Title: \(title)")
            print("   Artist: \(artist)")
            
            // Ensure audio session is active with proper error handling
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, deactivate the session to reset any conflicts
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ AudioManager: Failed to deactivate audio session: \(error)")
            }
            
            // Wait a bit before reactivating
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            
            // Try multiple approaches to activate the session
            var sessionActivated = false
            
            // Approach 1: Standard playback category
            if !sessionActivated {
                do {
                    try audioSession.setCategory(.playback, mode: .default, options: [])
                    try audioSession.setActive(true)
                    sessionActivated = true
                    print("✅ AudioManager: Audio session activated with standard approach")
                } catch {
                    print("⚠️ AudioManager: Standard audio session activation failed: \(error)")
                }
            }
            
            // Approach 2: Try without options
            if !sessionActivated {
                do {
                    try audioSession.setCategory(.playback, mode: .default)
                    try audioSession.setActive(true)
                    sessionActivated = true
                    print("✅ AudioManager: Audio session activated without options")
                } catch {
                    print("⚠️ AudioManager: Audio session activation without options failed: \(error)")
                }
            }
            
            // Approach 3: Try with different mode
            if !sessionActivated {
                do {
                    try audioSession.setCategory(.playback, mode: .moviePlayback)
                    try audioSession.setActive(true)
                    sessionActivated = true
                    print("✅ AudioManager: Audio session activated with moviePlayback mode")
                } catch {
                    print("⚠️ AudioManager: Audio session activation with moviePlayback failed: \(error)")
                }
            }
            
            // Approach 4: Last resort - minimal setup
            if !sessionActivated {
                do {
                    try audioSession.setActive(true)
                    sessionActivated = true
                    print("✅ AudioManager: Audio session activated with minimal setup")
                } catch {
                    print("❌ AudioManager: All audio session activation attempts failed: \(error)")
                    throw PlayerError.playbackError("Failed to activate audio session: \(error.localizedDescription)")
                }
            }
            
            let playerItem = AVPlayerItem(url: url)
            avPlayerItem = playerItem
            
            statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds
                    self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
                case .failed:
                    print("❌ AVPlayerItem failed to load: \(item.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            
            durationObserver = playerItem.observe(\.duration) { [weak self] item, _ in
                guard let self = self else { return }
                if item.duration.isValid {
                    self.duration = item.duration.seconds
                }
            }
            
            avPlayer = AVPlayer(playerItem: playerItem)
            avPlayer?.volume = 1.0
            
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self = self else { return }
                self.currentTime = time.seconds
            }
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            // AVPlayerItem이 준비될 때까지 더 오래 기다림
            var attempts = 0
            while playerItem.status != .readyToPlay && attempts < 30 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5초씩 대기
                attempts += 1
                print("🎵 AudioManager: Waiting for player item to be ready... attempt \(attempts)/30, status: \(playerItem.status.rawValue)")
            }
            
            guard playerItem.status == .readyToPlay else {
                print("❌ AudioManager: Player item failed to be ready after \(attempts) attempts")
                if let error = playerItem.error {
                    print("   Error: \(error.localizedDescription)")
                }
                
                // 파일이 존재하는지 다시 확인
                if FileManager.default.fileExists(atPath: url.path) {
                    print("   File exists but player item is not ready")
                } else {
                    print("   File does not exist at path: \(url.path)")
                }
                
                throw PlayerError.playbackError("AI music playback failed to start - item not ready after \(attempts) attempts")
            }
            
            avPlayer?.play()
            isPlayingMusic = true
            isPlayingAIMusic = true
            
            currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard await isPlaying() else {
                throw PlayerError.playbackError("AI music playback failed to start")
            }
        } catch {
            print("AudioManager Error: Failed to play AI music: \(error)")
            cleanupAIPlayback()
            throw error
        }
    }
    
    private func updateAITrackMetadata(title: String, artist: String) async {
        self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
        
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
        
        if isPlayingAIMusic {
            guard let player = avPlayer, let item = player.currentItem, item.status == .readyToPlay else {
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
            NotificationCenter.default.post(
                name: AudioManager.audioDidFinishNotification,
                object: nil
            )
        }
    }
    
    private func handlePlaybackError(_ error: Error) async {
        isPlayingMusic = false
        
        if isPlayingAIMusic {
            cleanupAIPlayback()
        } else {
            musicPlayerController.stop()
        }
    }
    
    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) async {
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
    }

    @objc private func playerItemDidReachEnd() {
        isPlayingMusic = false
        isPlayingAIMusic = false
        currentTime = 0
        
        cleanupAIPlayback()
        
        NotificationCenter.default.post(
            name: AudioManager.audioDidFinishNotification,
            object: nil
        )
    }
}
