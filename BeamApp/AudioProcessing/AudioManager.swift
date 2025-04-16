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
        setupNotifications()
        startTimerForMusicKit()
        musicPlayerController.repeatMode = .none
        handlePlaybackStateChange()
    }
    
    func play() async {
        if !isPlayingMusic {
            if isPlayingAIMusic {
                avPlayer?.play()
            } else {
                if avPlayer != nil { cleanupAIPlayback() }
                musicPlayerController.play()
            }
            isPlayingMusic = true
        }
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
    }
    
    func playAppleMusicTrack(with title: String) async throws {
        do {
            let authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else { throw PlayerError.musicAuthorizationFailed }
            let subscriptionStatus = try await MusicSubscription.current
            guard subscriptionStatus.canPlayCatalogContent else { throw PlayerError.noMusicSubscription }
            guard !title.isEmpty else { throw PlayerError.invalidTrackTitle }
            
            if isPlayingAIMusic {
                cleanupAIPlayback()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            var catalogSearchRequest = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
            catalogSearchRequest.limit = 1
            let response = try await catalogSearchRequest.response()
            guard let song = response.songs.first else { throw PlayerError.trackNotFound(title) }
            
            await playMusicWithPlayerController(song: song)
            isPlayingMusic = true
            
        } catch {
            isPlayingMusic = false
            currentTrackMetadata = (nil, nil, nil)
            currentTime = 0
            duration = 0
            throw error
        }
    }
    
    func playAIMusic(from urlString: String) async {
        guard let requestedURL = URL(string: urlString) else {
            await handlePlaybackError(PlayerError.invalidURL(urlString))
            return
        }
        
        if isPlayingAIMusic,
           let currentPlayer = avPlayer,
           let currentItem = currentPlayer.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           currentURL == requestedURL {
            if isPlayingMusic {
                return
            }
            else {
                currentPlayer.play()
                isPlayingMusic = true
                startPeriodicTimeObserver()
                return
            }
        }
        
        if !isPlayingAIMusic && (musicPlayerController.playbackState == .playing) {
            musicPlayerController.pause()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        }
        
        cleanupAIPlayback()
        
        let filename = requestedURL.lastPathComponent
        currentTrackMetadata = (
            title: filename.components(separatedBy: ".").first ?? "AI Generated Music",
            artist: "AI Composer",
            albumArt: nil
        )
        
        let asset = AVAsset(url: requestedURL)
        let playerItem = AVPlayerItem(asset: asset)
        avPlayer = AVPlayer(playerItem: playerItem)
        
        
        removeAVPlayerObservers()
        avPlayerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.aiTrackDidFinish()
        }
        
        currentTime = 0
        duration = 0
        
        isPlayingAIMusic = true
        isPlayingMusic = true
        
        avPlayer?.play()
        startPeriodicTimeObserver()
    }
    
    func isPlaying() -> Bool {
        return self.isPlayingMusic
    }
    
    func seek(to seconds: Double) async {
        let targetTime = max(0, seconds)
        
        if isPlayingAIMusic {
            guard let player = avPlayer, let item = player.currentItem,
                  item.status == .readyToPlay else {
                return
            }
            
            let time = CMTime(seconds: targetTime, preferredTimescale: 600)
            
            self.currentTime = targetTime
            
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            
        } else { // Apple Music
            if let itemDuration = musicPlayerController.nowPlayingItem?.playbackDuration, itemDuration > 0 {
                let boundedTime = min(targetTime, itemDuration)
                
                self.currentTime = boundedTime
                
                musicPlayerController.currentPlaybackTime = boundedTime
            }
        }
    }
    
    private func startTimerForMusicKit() {
        timer?.invalidate() // 기존 타이머 중지
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
                if abs(currentTime - newTime) > 0.1 {
                    currentTime = newTime
                }
            }
            
            let newDuration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
            if newDuration.isFinite && newDuration > 0 {
                if duration != newDuration {
                    duration = newDuration
                }
            } else if duration != 0 {
                duration = 0
            }
            checkForAppleMusicTrackCompletion()
        }
    }
    
    private func startPeriodicTimeObserver() {
        removePeriodicTimeObserver()
        guard let player = avPlayer else { return }
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: Int32(NSEC_PER_SEC)), queue: .main) { [weak self] time in
            guard let self = self, self.isPlayingAIMusic else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite && seconds >= 0 {
                if abs(self.currentTime - seconds) > 0.05 {
                    self.currentTime = seconds
                }
                if let item = self.avPlayer?.currentItem, item.status == .readyToPlay {
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if itemDuration.isNormal && itemDuration > 0 && itemDuration.isFinite {
                        if self.duration != itemDuration {
                            self.duration = itemDuration
                        }
                    }
                }
            }
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func cleanupAIPlayback() {
        removePeriodicTimeObserver()
        removeAVPlayerObservers()
        if let player = avPlayer {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        avPlayer = nil
        isPlayingAIMusic = false
    }
    
    private func removeAVPlayerObservers() {
        if let observer = avPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            avPlayerItemObserver = nil
        }
    }
    
    private func aiTrackDidFinish() {
        guard isPlayingAIMusic else { return }
        
        cleanupAIPlayback()
        
        isPlayingMusic = false
        currentTime = 0
        // duration = 0 // 필요시 초기화, 다음 곡 정보 로드시 덮어쓰여짐
        NotificationCenter.default.post(name: AudioManager.audioDidFinishNotification, object: nil)
    }
    
    private func setupNotifications() {
        // MusicKit 상태 변경 알림
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
        guard !isPlayingAIMusic else {
            
            return
        }
        
        let newState = musicPlayerController.playbackState
        let isNowPlaying = (newState == .playing)
        
        if isPlayingMusic != isNowPlaying {
            isPlayingMusic = isNowPlaying // @Published 업데이트
            // 재생 상태 변경 시 시간/기간도 즉시 업데이트 시도
            updateMusicKitPlaybackProgress()
        }
        
        // 현재 아이템 변경도 여기서 확인 (상태 변경과 아이템 변경이 같이 올 수 있음)
        handleNowPlayingItemChange()
    }
    
    // MusicKit 아이템 변경 처리
    private func handleNowPlayingItemChange() {
        // AI 재생 중에는 MusicKit 아이템 변경 무시
        guard !isPlayingAIMusic else {
            print("   -> Ignoring MusicKit item change during AI playback.")
            return
        }
        
        let currentItem = musicPlayerController.nowPlayingItem
        
        let needsMetadataUpdate = (currentTrackMetadata.title != currentItem?.title || currentTrackMetadata.artist != currentItem?.artist)
        
        if let item = currentItem {
            if needsMetadataUpdate {
                currentTrackMetadata = (
                    title: item.title,
                    artist: item.artist,
                    albumArt: item.artwork?.image(at: CGSize(width: 300, height: 300))
                )
                let newDuration = item.playbackDuration
                if newDuration.isFinite && newDuration > 0 {
                    duration = newDuration
                } else {
                    duration = 0
                }
                currentTime = musicPlayerController.currentPlaybackTime
            }
        } else {
            if currentTrackMetadata.title != nil || currentTrackMetadata.artist != nil {
                currentTrackMetadata = (nil, nil, nil)
                currentTime = 0
                duration = 0
                // isPlayingMusic = false // playbackState 변경 시 처리됨
            }
        }
    }
    
    // MusicKit 트랙 완료 확인 (타이머에서 호출)
    private func checkForAppleMusicTrackCompletion() {
        guard !isPlayingAIMusic, isPlayingMusic else { return }
        
        // 끝에 매우 가깝거나(0.5초 이내) 시간이 duration을 넘어선 경우 완료로 간주
        if duration > 0 && (currentTime >= duration - 0.5 || currentTime > duration) {
            NotificationCenter.default.post(
                name: AudioManager.audioDidFinishNotification,
                object: nil
            )
            // TODO: 알림 보낸 후 즉시 isPlayingMusic=false로 할지, 아니면 audioDidFinish 액션 처리에 맡길지 결정
        }
    }
    
    @MainActor
    private func playMusicWithPlayerController(song: MusicKit.Song) async {
        let storeID = song.id.rawValue
        if musicPlayerController.nowPlayingItem?.playbackStoreID != storeID {
            musicPlayerController.setQueue(with: [storeID])
            musicPlayerController.play()
        } else if musicPlayerController.playbackState != .playing {
            musicPlayerController.play()
        }
        await updateTrackMetadata(song: song)
        self.isPlayingMusic = true
    }
    
    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) async {
        self.currentTrackMetadata = (title: song.title, artist: song.artistName, albumArt: nil)
        Task {
            if let artwork = song.artwork, let url = artwork.url(width: 300, height: 300) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    self.currentTrackMetadata.albumArt = UIImage(data: data)
                } catch {
                }
            }
        }
    }
    
    
    private func handlePlaybackError(_ error: Error) async {
        
        isPlayingMusic = false
        if isPlayingAIMusic {
            cleanupAIPlayback()
        }
        // TODO: Reducer에 에러 전달하는 메커니즘 필요
    }
    
    
    deinit {
        
        timer?.invalidate() // MusicKit 타이머 중지
        musicPlayerController.endGeneratingPlaybackNotifications()
        if let observer = playbackStateObserver { NotificationCenter.default.removeObserver(observer) }
        //        removeAVPlayerObservers() // AVPlayer 관련 옵저버 제거
        //        removePeriodicTimeObserver()  AVPlayer 시간 옵저버 제거
        NotificationCenter.default.removeObserver(self) // 모든 알림 구독 해제
    }
}
