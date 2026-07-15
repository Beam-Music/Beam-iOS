import AVFoundation
import SwiftUI
import Combine
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
        case .musicAuthorizationFailed: return "Apple Music access permission is required."
        case .noMusicSubscription: return "An Apple Music subscription is required."
        case .invalidTrackTitle: return "Invalid song title."
        case .trackNotFound(let title): return "Could not find song: '\(title)'."
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Data processing error: \(error.localizedDescription)"
        case .unknownError(let error): return "Unknown error: \(error.localizedDescription)"
        case .playbackError(let message): return "Playback error: \(message)"
        }
    }
}

@MainActor
final class AudioManager: ObservableObject, @preconcurrency AudioManagerProtocol {
    static let shared = AudioManager()

    private var avPlayer: AVPlayer?
    private var avPlayerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var avPlayerItemObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var currentNowPlayingTitle: String?
    private var currentNowPlayingArtist: String?
    private var currentNowPlayingArtwork: UIImage?
    private var lastNowPlayingUpdateSecond: Int = -1
    
    private var isPlayingAIMusic: Bool = false
    var isAIPlaying: Bool {
        return self.isPlayingAIMusic
    }
    
    var pendingSeekPosition: Double?
    
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
    
    static let audioDidFinishNotification = Notification.Name("AudioDidFinish")
    
    private init() {
        setupAudioSession()
        setupNotifications()
        setupRemoteCommands()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            avPlayer?.pause()
            isPlayingMusic = false

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                avPlayer?.play()
                isPlayingMusic = true
            }

        @unknown default:
            break
        }
    }
    
    func play() async {
        guard !isPlayingMusic, let player = avPlayer else {
            return
        }
        player.play()
        isPlayingMusic = true
        updateNowPlayingPlaybackState()
    }
    
    func tryResume() async -> Bool {
        if !isPlayingMusic {
            if let player = avPlayer, player.rate == 0 {
                player.play()
                isPlayingMusic = true
                updateNowPlayingPlaybackState()
                return true
            }
        }
        return false
    }
    
    func pause() async {
        if isPlayingMusic {
            avPlayer?.pause()
            isPlayingMusic = false
            updateNowPlayingPlaybackState()
        }
    }
    
    func stop() async {
        cleanupAIPlayback()
        currentTime = 0
        duration = 0
        isPlayingMusic = false
        isPlayingAIMusic = false
        pendingSeekPosition = nil
        currentTrackMetadata = (nil, nil, nil)
        clearNowPlayingInfo()
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
    
    func playAIMusic(from urlString: String, title: String, artist: String, artworkURL: URL? = nil) async throws {
        let savedPendingSeek = pendingSeekPosition
        await stop()
        pendingSeekPosition = savedPendingSeek
        
        let resolvedURLString: String
        if urlString.hasPrefix("/v1/") {
            let separator = urlString.contains("?") ? "&" : "?"
            resolvedURLString = "https://api.audius.co\(urlString)\(separator)app_name=beamapp"
        } else {
            resolvedURLString = urlString
        }

        let url: URL
        if resolvedURLString.hasPrefix("file://") {
            // 이미 완전한 URL인 경우
            guard let fullURL = URL(string: resolvedURLString) else {
                throw PlayerError.invalidURL(resolvedURLString)
            }
            url = fullURL
        } else if resolvedURLString.hasPrefix("/") {
            // 파일 경로인 경우
            url = URL(fileURLWithPath: resolvedURLString)
        } else {
            // 일반 URL인 경우
            guard let fullURL = URL(string: resolvedURLString) else {
                throw PlayerError.invalidURL(resolvedURLString)
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
                    let duration = item.duration.seconds
                    Task { @MainActor in
                        self.duration = duration
                        await self.updateTrackMetadata(title: title, artist: artist, artworkURL: artworkURL)
                    }
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
                    let duration = item.duration.seconds
                    Task { @MainActor in
                        self.duration = duration
                    }
                }
            }
            
            avPlayer = AVPlayer(playerItem: playerItem)
            avPlayer?.volume = 1.0
            
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self = self else { return }
                let currentTime = time.seconds
                Task { @MainActor in
                    self.currentTime = currentTime
                    let currentSecond = Int(currentTime.rounded(.down))
                    if currentSecond != self.lastNowPlayingUpdateSecond {
                        self.lastNowPlayingUpdateSecond = currentSecond
                        self.updateNowPlayingPlaybackState()
                    }
                }
            }
            
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            // Avoid making the app feel stuck when a remote stream is slow or never becomes playable.
            var attempts = 0
            while playerItem.status == .unknown && attempts < 8 {
                try await Task.sleep(nanoseconds: 250_000_000)
                attempts += 1
                print("🎵 AudioManager: Waiting for player item to be ready... attempt \(attempts)/8, status: \(playerItem.status.rawValue)")
            }
            
            guard playerItem.status == .readyToPlay else {
                print("❌ AudioManager: Player item failed to be ready after \(attempts) attempts")
                if let error = playerItem.error {
                    print("   Error: \(error.localizedDescription)")
                }
                
                // Check whether local file sources still exist.
                if FileManager.default.fileExists(atPath: url.path) {
                    print("   File exists but player item is not ready")
                } else {
                    print("   File does not exist at path: \(url.path)")
                }
                
                throw PlayerError.playbackError("Audio playback failed to start - item status: \(playerItem.status.rawValue)")
            }
            
            avPlayer?.play()
            isPlayingMusic = true
            isPlayingAIMusic = true
            updateNowPlayingInfo(title: title, artist: artist, artwork: currentNowPlayingArtwork)
            
            await updateTrackMetadata(title: title, artist: artist, artworkURL: artworkURL)
            
            if let seekPos = pendingSeekPosition {
                pendingSeekPosition = nil
                await seek(to: seekPos)
            }
            
            guard avPlayer?.currentItem?.status == .readyToPlay else {
                throw PlayerError.playbackError("Audio playback failed to start")
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
        removeAVPlayerObservers()
        removePeriodicTimeObserver()
        durationObserver?.invalidate()
        durationObserver = nil
        avPlayer?.replaceCurrentItem(with: nil)
        avPlayer = nil
        avPlayerItem = nil
        isPlayingAIMusic = false
        currentTime = 0
        duration = 0
        clearNowPlayingInfo()
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
        guard let player = avPlayer, let item = player.currentItem, item.status == .readyToPlay else {
            return
        }

        let wasPlaying = isPlayingMusic || player.rate > 0
        let time = CMTime(seconds: targetTime, preferredTimescale: 600)

        await withCheckedContinuation { continuation in
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }

        self.currentTime = targetTime
        updateNowPlayingPlaybackState()

        if wasPlaying, player.rate == 0 {
            player.play()
            isPlayingMusic = true
            updateNowPlayingPlaybackState()
        }
    }
    
    private func handlePlaybackError(_ error: Error) async {
        isPlayingMusic = false
        cleanupAIPlayback()
    }
    
    @MainActor
    private func updateTrackMetadata(title: String, artist: String, artworkURL: URL?) async {
        self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)
        updateNowPlayingInfo(title: title, artist: artist, artwork: nil)

        Task.detached {
            let image: UIImage?
            if let artworkURL = artworkURL {
                do {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    image = UIImage(data: data)
                } catch {
                    print("AudioManager Error: Failed loading artwork: \(error)")
                    image = nil
                }
            } else {
                image = nil
            }
            await MainActor.run {
                if self.currentTrackMetadata.title == title {
                    self.currentTrackMetadata.albumArt = image
                    self.updateNowPlayingInfo(title: title, artist: artist, artwork: image)
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                await self.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                await self.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                if self.isPlayingMusic {
                    await self.pause()
                } else {
                    await self.play()
                }
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            Task { @MainActor in
                await self.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo(title: String, artist: String, artwork: UIImage?) {
        currentNowPlayingTitle = title
        currentNowPlayingArtist = artist
        currentNowPlayingArtwork = artwork
        updateNowPlayingPlaybackState()
    }

    private func updateNowPlayingPlaybackState() {
        guard let title = currentNowPlayingTitle else { return }

        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentNowPlayingArtist ?? "Unknown Artist"

        if let artwork = currentNowPlayingArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        } else {
            nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlayingMusic ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        currentNowPlayingTitle = nil
        currentNowPlayingArtist = nil
        currentNowPlayingArtwork = nil
        lastNowPlayingUpdateSecond = -1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func cleanup() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        removeAVPlayerObservers()
        removePeriodicTimeObserver()
        durationObserver?.invalidate()
        durationObserver = nil

        if avPlayer != nil {
            avPlayer?.pause()
            avPlayer?.replaceCurrentItem(with: nil)
            avPlayer = nil
        }
        clearNowPlayingInfo()
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
