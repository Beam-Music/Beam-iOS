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
                    print("AudioManager: Resuming paused AI track.")
                    player.play()
                    isPlayingMusic = true
                    return true
                }
            } else {
                if musicPlayerController.playbackState == .paused {
                    print("AudioManager: Resuming paused MusicKit track.")
                    musicPlayerController.play()
                    return true
                }
            }
        }
        print("AudioManager: tryResume failed - already playing or cannot resume.")
        return false
    }
    
    func pause() async {
        if isPlayingMusic {
            if isPlayingAIMusic {
                avPlayer?.pause()
                print("AudioManager: Pausing AI playback.")
            } else {
                musicPlayerController.pause()
                print("AudioManager: Pausing MusicKit playback.")
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
    
    func playAppleMusicTrack(title: String? = nil, storeID: String? = nil) async throws {
        print("AudioManager: playAppleMusicTrack called with storeID: \(storeID ?? "nil"), title: \(title ?? "nil")")
        do {
            let authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else { throw PlayerError.musicAuthorizationFailed }
            
            var trackStoreID: String? = storeID
            
            if (trackStoreID == nil || trackStoreID!.isEmpty), let searchTitle = title, !searchTitle.isEmpty {
                print("AudioManager: StoreID missing. Searching catalog by title: \(searchTitle)")
                var catalogSearchRequest = MusicCatalogSearchRequest(term: searchTitle, types: [MusicKit.Song.self])
                catalogSearchRequest.limit = 1
                let response = try await catalogSearchRequest.response()
                guard let song = response.songs.first else {
                    print("AudioManager Error: Track not found by title: \(searchTitle)")
                    throw PlayerError.trackNotFound(searchTitle)
                }
                trackStoreID = song.id.rawValue
                print("AudioManager: Found storeID by title: \(trackStoreID ?? "N/A")")
            }
            
            guard let finalStoreID = trackStoreID, !finalStoreID.isEmpty else {
                print("AudioManager Error: Could not determine valid MusicKit Store ID.")
                throw PlayerError.trackNotFound("MusicKit track ID missing.")
            }
            
            if isPlayingAIMusic {
                print("AudioManager: Cleaning up AI playback before starting MusicKit.")
                cleanupAIPlayback()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            print("AudioManager: Setting MusicKit queue with Store ID: \(finalStoreID)")
            if musicPlayerController.nowPlayingItem?.playbackStoreID != finalStoreID || musicPlayerController.playbackState != .playing {
                musicPlayerController.setQueue(with: [finalStoreID])
                musicPlayerController.play()
            } else {
                print("AudioManager: Track \(finalStoreID) already in queue/playing.")
                if musicPlayerController.playbackState != .playing { musicPlayerController.play() }
            }
            
            Task.detached {
                do {
                    var request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(finalStoreID))
                    request.limit = 1
                    let response = try await request.response()
                    if let fetchedSong = response.items.first {
                        await self.updateTrackMetadata(song: fetchedSong)
                    }
                } catch {
                    print("AudioManager Error: Failed fetching full Song details for \(finalStoreID): \(error)")
                }
            }
            
            self.isPlayingAIMusic = false
            
        } catch {
            print("AudioManager Error in playAppleMusicTrack: \(error)")
            await handlePlaybackError(error)
            throw error
        }
    }
    
    func playAIMusic(from urlString: String) async throws {
        print("AudioManager: playAIMusic called with URL: \(urlString)")
        guard let requestedURL = URL(string: urlString) else {
            print("AudioManager Error: Invalid URL string.")
            throw PlayerError.invalidURL(urlString)
        }
        
        if isPlayingAIMusic, let player = avPlayer, let item = player.currentItem,
           let currentURL = (item.asset as? AVURLAsset)?.url, currentURL == requestedURL {
            print("AudioManager: Requested AI track is already loaded.")
            if !isPlayingMusic {
                player.play()
                isPlayingMusic = true
                startPeriodicTimeObserver()
            }
            return
        }
        
        if !isPlayingAIMusic && (musicPlayerController.playbackState == .playing) {
            print("AudioManager: Pausing MusicKit to play AI track.")
            musicPlayerController.pause()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        print("AudioManager: Cleaning up previous AI playback (if any).")
        cleanupAIPlayback()
        
        let filename = requestedURL.lastPathComponent
        currentTrackMetadata = (
            title: filename.components(separatedBy: ".").first ?? "AI Generated Music",
            artist: "AI Composer",
            albumArt: nil
        )
        
        print("AudioManager: Setting up AVPlayer for AI track.")
        let asset = AVURLAsset(url: requestedURL)
        let playerItem = AVPlayerItem(asset: asset)
        self.avPlayerItem = playerItem
        
        removeAVPlayerObservers()
        setupAVPlayerObservers(for: playerItem)
        
        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer?.automaticallyWaitsToMinimizeStalling = true
        
        currentTime = 0
        duration = 0
        isPlayingAIMusic = true
        isPlayingMusic = true
        
        avPlayer?.play()
        startPeriodicTimeObserver()
        print("AudioManager: AI playback started.")
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
    
    private func startPeriodicTimeObserver() {
        removePeriodicTimeObserver()
        guard let player = avPlayer else { return }
        print("AudioManager: Starting AVPlayer time observer.")
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, self.isPlayingAIMusic else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite && seconds >= 0 {
                if abs(self.currentTime - seconds) > 0.05 { self.currentTime = seconds }
                if let item = self.avPlayer?.currentItem, item.status == .readyToPlay {
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if itemDuration.isNormal && itemDuration > 0 && itemDuration.isFinite {
                        if self.duration != itemDuration { self.duration = itemDuration }
                    }
                }
            }
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
            print("AudioManager: Removed AVPlayer time observer.")
        }
    }
    
    private func cleanupAIPlayback() {
        print("AudioManager: Cleaning up AI playback resources.")
        removePeriodicTimeObserver()
        removeAVPlayerObservers()
        if let player = avPlayer {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        avPlayer = nil
        avPlayerItem = nil
        isPlayingAIMusic = false
    }
    
    private func setupAVPlayerObservers(for playerItem: AVPlayerItem) {
        statusObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    print("AudioManager: AVPlayerItem status: readyToPlay.")
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if itemDuration.isNormal && itemDuration > 0 && itemDuration.isFinite {
                        if self.duration != itemDuration {
                            self.duration = itemDuration
                            print("AudioManager: Updated duration from KVO: \(itemDuration)")
                        }
                    } else {
                        print("AudioManager Warning: AVPlayerItem ready, but duration is invalid: \(itemDuration)")
                        if self.duration != 0 { self.duration = 0 }
                    }
                case .failed:
                    let error = item.error ?? PlayerError.playbackError("AVPlayerItem status failed.")
                    print("AudioManager Error: AVPlayerItem status: failed. Error: \(error.localizedDescription)")
                    await self.handlePlaybackError(error)
                case .unknown:
                    print("AudioManager: AVPlayerItem status: unknown.")
                @unknown default:
                    print("AudioManager: AVPlayerItem status: unexpected value.")
                }
            }
        }
        
        avPlayerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main) { [weak self] _ in
                print("AudioManager: AVPlayerItemDidPlayToEndTime notification received.")
                self?.aiTrackDidFinish()
        }
        print("AudioManager: Added AVPlayer observers.")
    }
    
    private func removeAVPlayerObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let observer = avPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            avPlayerItemObserver = nil
        }
        print("AudioManager: Removed AVPlayer observers.")
    }
    
    private func aiTrackDidFinish() {
        guard isPlayingAIMusic else { return }
        print("AudioManager: aiTrackDidFinish called.")
        
        isPlayingMusic = false
        currentTime = 0
        
        cleanupAIPlayback()
        
        print("AudioManager: Posting audioDidFinishNotification.")
        NotificationCenter.default.post(name: AudioManager.audioDidFinishNotification, object: nil)
    }
    
    private func setupNotifications() {
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayerController,
            queue: .main) { [weak self] _ in
                self?.handlePlaybackStateChange()
        }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayerController,
            queue: .main) { [weak self] _ in
                print("AudioManager: NowPlayingItemDidChange notification received.")
                self?.handleNowPlayingItemChange()
        }
        musicPlayerController.beginGeneratingPlaybackNotifications()
        print("AudioManager: Setup MusicKit notifications.")
    }
    
    private func handlePlaybackStateChange() {
        guard !isPlayingAIMusic else {
            print("AudioManager: Ignoring MusicKit state change during AI playback.")
            return
        }
        
        let newState = musicPlayerController.playbackState
        let isNowPlaying = (newState == .playing)
        print("AudioManager: MusicKit PlaybackState changed to: \(newState.rawValue)")
        
        if isPlayingMusic != isNowPlaying {
            isPlayingMusic = isNowPlaying
            print("AudioManager: Updated isPlayingMusic to \(isPlayingMusic) from notification.")
        }
        
        updateMusicKitPlaybackProgress()
        handleNowPlayingItemChange()
    }
    
    private func handleNowPlayingItemChange() {
        guard !isPlayingAIMusic else { return }
        
        let currentItem = musicPlayerController.nowPlayingItem
        print("AudioManager: Handling NowPlayingItem change. New item title: \(currentItem?.title ?? "nil")")
        
        if let item = currentItem {
            if currentTrackMetadata.title != item.title || currentTrackMetadata.artist != item.artist {
                print("AudioManager: Updating metadata for MusicKit track: \(item.title ?? "N/A")")
                currentTrackMetadata = (
                    title: item.title,
                    artist: item.artist,
                    albumArt: item.artwork?.image(at: CGSize(width: 300, height: 300))
                )
                let newDuration = item.playbackDuration
                duration = (newDuration.isFinite && newDuration > 0) ? newDuration : 0
                currentTime = musicPlayerController.currentPlaybackTime
            }
        } else {
            if currentTrackMetadata.title != nil || currentTrackMetadata.artist != nil {
                print("AudioManager: MusicKit NowPlayingItem is nil. Clearing metadata.")
                currentTrackMetadata = (nil, nil, nil)
                currentTime = 0
                duration = 0
            }
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
}
