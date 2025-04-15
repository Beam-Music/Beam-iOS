import AVFoundation
import SwiftUI
import Combine
import MusicKit
import MediaPlayer

@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer
    private var playbackStateObserver: NSObjectProtocol?

    private var avPlayer: AVPlayer?
    private var avPlayerItemObserver: NSObjectProtocol?
    private var isPlayingAIMusic: Bool = false

    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying: Bool = false

    private var timer: Timer?
    static let audioDidFinishNotification = Notification.Name("AudioDidFinish")

    private init() {
        setupNotifications()
        startTimer()
        musicPlayerController.repeatMode = .none
        handlePlaybackStateChange()
    }

    private func setupNotifications() {
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayerController,
            queue: .main // 메인 스레드에서 처리
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }
        musicPlayerController.beginGeneratingPlaybackNotifications()
    }

    private func handlePlaybackStateChange() {
        switch musicPlayerController.playbackState {
        case .stopped, .paused, .interrupted:
             if !isPlayingAIMusic {
                 if isPlaying {
                      isPlaying = false
                 }
             }
        case .playing:
             if !isPlayingAIMusic {
                 if !isPlaying {
                      isPlaying = true
                 }
             }
        default:
            break
        }
        handleNowPlayingItemChange()
    }

    private func handleNowPlayingItemChange() {
        guard !isPlayingAIMusic else { return }

        if let currentItem = musicPlayerController.nowPlayingItem {
             if currentTrackMetadata.title != currentItem.title || currentTrackMetadata.artist != currentItem.artist {
                 currentTrackMetadata = (
                     title: currentItem.title,
                     artist: currentItem.artist,
                     albumArt: currentItem.artwork?.image(at: CGSize(width: 300, height: 300))
                 )
                 duration = currentItem.playbackDuration
             }
        } else {
             if currentTrackMetadata.title != nil || currentTrackMetadata.artist != nil {
                 currentTrackMetadata = (nil, nil, nil)
                 currentTime = 0
                 duration = 0
             }
        }
    }

    private func startTimer() {
        print("AudioManager: Starting unified timer.")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
             self?.updatePlaybackProgress()
        }
    }

    private func updatePlaybackProgress() {
        if isPlayingAIMusic {
            if let player = avPlayer, let item = player.currentItem {
                if item.status == .readyToPlay {
                    let newTime = CMTimeGetSeconds(player.currentTime())
                    if abs(currentTime - newTime) > 0.1 {
                         currentTime = newTime
                    }
                    let itemDuration = CMTimeGetSeconds(item.duration)
                    if itemDuration.isNormal && itemDuration > 0 && !self.duration.isNormal {
                         duration = itemDuration
                    }
                }
            }
        } else {
            let newTime = musicPlayerController.currentPlaybackTime
            let newDuration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
            if abs(currentTime - newTime) > 0.1 { currentTime = newTime }
            if abs(duration - newDuration) > 0.1 { duration = newDuration }

            checkForAppleMusicTrackCompletion()
        }
    }

    private func checkForAppleMusicTrackCompletion() {
        guard !isPlayingAIMusic, isPlaying else { return }

        if duration > 0 && abs(duration - currentTime) <= 1.0 {
            NotificationCenter.default.post(
                name: AudioManager.audioDidFinishNotification,
                object: nil
            )
        }
    }

    func playAppleMusicTrack(with title: String) async throws {
        do {
            let authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else { /* Error */ throw NSError(domain: "AudioManager", code: 1) }
            let subscriptionStatus = try await MusicSubscription.current
            guard subscriptionStatus.canPlayCatalogContent else { /* Error */ throw NSError(domain: "AudioManager", code: 2) }
            guard !title.isEmpty else { /* Error */ throw NSError(domain: "AudioManager", code: 3) }

            var catalogSearchRequest = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
            catalogSearchRequest.limit = 1
            let response = try await catalogSearchRequest.response()
            guard let song = response.songs.first else { /* Error */ throw NSError(domain: "AudioManager", code: 4) }

            if isPlayingAIMusic {
                 await pause()
            }
            await playMusicWithPlayerController(song: song)

        } catch {
             print("Error in playAppleMusicTrack: \(error)")
             throw error
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
        } else {
            print("Already playing \(storeID).")
        }
         await updateTrackMetadata(song: song) // 메타데이터 업데이트
    }

    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) {
        self.currentTrackMetadata = (title: song.title, artist: song.artistName, albumArt: nil)
        Task {
            if let artwork = song.artwork, let url = artwork.url(width: 300, height: 300) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                         self.currentTrackMetadata.albumArt = UIImage(data: data)
                } catch { print("Failed to load artwork image: \(error)") }
            }
        }
    }

    @MainActor
    func queueNextTrack(trackTitle: String) async {
    }

    @MainActor
    func playAIMusic(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            // TODO: Reducer에 에러 전달
            return
        }

        if isPlaying && !isPlayingAIMusic {
             musicPlayerController.pause()
        } else if isPlaying && isPlayingAIMusic {
             avPlayer?.pause() // 이전 AVPlayer 중지
             if let observer = avPlayerItemObserver { NotificationCenter.default.removeObserver(observer) }
        }

        print("Setting up AVPlayer for AI music")
        let playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem)

        // 완료 알림 옵저버 설정 (메인 스레드에서 콜백 실행)
        avPlayerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main // <-- 메인 큐 지정!
        ) { [weak self] _ in
             self?.aiTrackDidFinish() // @MainActor 함수 호출
        }

        // 재생 시작
        avPlayer?.play()
        isPlayingAIMusic = true // AI 재생 플래그 설정
        isPlaying = true      // @Published 변경 (메인 스레드 OK)

        // 메타데이터 업데이트 (@Published 변경)
        print("Updating metadata for AI Song: \(url.lastPathComponent)")
        let filename = url.lastPathComponent
        // TODO: 실제 메타데이터 사용 (DTO에서 전달받거나, 여기서 별도 조회?)
        currentTrackMetadata = (
            title: filename.components(separatedBy: ".").first ?? "AI Generated Music",
            artist: "AI Composer", // 실제 아티스트 정보 사용
            albumArt: nil // AI 노래 아트워크?
        )
        // AI 재생 시작 시 시간/기간 초기화 및 타이머 확인
        currentTime = 0
        duration = 0 // 로드 후 updatePlaybackProgress에서 설정됨
        // 타이머는 계속 돌고 있음 (startTimer 호출 불필요)
    }

    // AI 트랙 완료 처리 (메인 스레드 실행 보장)
    private func aiTrackDidFinish() {
        print("AudioManager: aiTrackDidFinish called")
        // 상태 초기화
        isPlayingAIMusic = false
        // isPlaying은 여기서 false로 설정 (handlePlaybackStateChange는 AVPlayer 상태 모름)
        isPlaying = false
        currentTime = 0
        duration = 0
        avPlayer = nil // 플레이어 해제

        if let observer = avPlayerItemObserver {
             NotificationCenter.default.removeObserver(observer)
             avPlayerItemObserver = nil
        }
        NotificationCenter.default.post(name: AudioManager.audioDidFinishNotification, object: nil)
    }

    @MainActor
    func pause() {
        print("AudioManager: pause called. isPlaying: \(isPlaying), isPlayingAI: \(isPlayingAIMusic)")
        if isPlaying { // 재생 중일 때만 pause 의미 있음
             if isPlayingAIMusic {
                 avPlayer?.pause()
             } else {
                 musicPlayerController.pause()
             }
             isPlaying = false // @Published 변경
        }
    }

    @MainActor
    func play() {
        if !isPlaying {
             if isPlayingAIMusic {
                 avPlayer?.play()
             } else {
                 musicPlayerController.play()
             }
             isPlaying = true
        }
    }

    @MainActor
    func seek(to seconds: Double) {
        let targetTime = max(0, seconds)
        if isPlayingAIMusic {
            let time = CMTime(seconds: targetTime, preferredTimescale: 600)
            avPlayer?.seek(to: time) { [weak self] completed in
                 if completed {
                      self?.currentTime = targetTime
                 }
            }
            currentTime = targetTime
        } else {
            if let itemDuration = musicPlayerController.nowPlayingItem?.playbackDuration, itemDuration > 0 {
                 musicPlayerController.currentPlaybackTime = min(targetTime, itemDuration)
                 currentTime = musicPlayerController.currentPlaybackTime
            }
        }
    }

    func getCurrentTime() -> Double { return currentTime }
    func getDuration() -> Double { return duration }

    @MainActor
    func stop() {
        if isPlayingAIMusic {
            avPlayer?.pause()
            avPlayer?.seek(to: .zero)
        } else {
            musicPlayerController.stop()
        }
        currentTime = 0
        isPlaying = false
        isPlayingAIMusic = false
        timer?.invalidate()
        startTimer()
    }
    @MainActor
    func reset() {
        stop()
        avPlayer = nil
        currentTrackMetadata = (nil, nil, nil)
        duration = 0
        
        if let observer = avPlayerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            avPlayerItemObserver = nil
        }
    }

    deinit {
        timer?.invalidate()
        musicPlayerController.endGeneratingPlaybackNotifications()
        if let observer = playbackStateObserver { NotificationCenter.default.removeObserver(observer) }
        // if let observer = nowPlayingObserver { NotificationCenter.default.removeObserver(observer) } // 현재 미사용
        if let observer = avPlayerItemObserver { NotificationCenter.default.removeObserver(observer) }
        NotificationCenter.default.removeObserver(self) //
    }
}

private func formatTime(_ time: Double) -> String {
    guard time.isFinite, time >= 0 else { return "--:--" }
    let totalSeconds = Int(time)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
