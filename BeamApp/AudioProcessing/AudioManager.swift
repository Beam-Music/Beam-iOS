import AVFoundation
import SwiftUI
import Combine // Needed for ObservableObject
import MusicKit
import MediaPlayer

// MARK: - Custom Errors (Example)
// 다양한 오류 상황을 좀 더 명확하게 표현
enum PlayerError: Error, LocalizedError {
    case musicAuthorizationFailed
    case noMusicSubscription
    case invalidTrackTitle
    case trackNotFound(String)
    case invalidURL(String)
    case networkError(Error)
    case decodingError(Error)
    case unknownError(Error)
    case playbackError(String) // 기존 에러 포함

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


// MARK: - AudioManager Implementation (개선된 버전)
@MainActor
final class AudioManager: ObservableObject, AudioManagerProtocol { // ✅ AudioManagerProtocol 채택
    static let shared = AudioManager() // 싱글톤 유지

    // --- Players ---
    let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer
    private var avPlayer: AVPlayer?

    // --- Observers ---
    private var playbackStateObserver: NSObjectProtocol? // MusicKit 상태 변경 감지
    private var avPlayerItemObserver: NSObjectProtocol? // AVPlayer 완료 감지
    private var timeObserver: Any? // AVPlayer 시간 관찰자

    // --- State Flags ---
    private var isPlayingAIMusic: Bool = false // AI 음악 재생 여부 플래그
    var isAIPlaying: Bool {
            // 내부 플래그 값을 반환
            return self.isPlayingAIMusic
        }

    // --- Published Properties (View에서 관찰) ---
    @Published var currentTrackMetadata: (title: String?, artist: String?, albumArt: UIImage?) = (nil, nil, nil)
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlayingMusic: Bool = false // 통합된 재생 상태 (@Published)

    // --- Internal Timer (MusicKit 전용) ---
    private var timer: Timer?
    static let audioDidFinishNotification = Notification.Name("AudioDidFinish") // 완료 알림

    // --- Initialization ---
    private init() {
        print("AudioManager: init")
        setupNotifications()
        startTimerForMusicKit() // MusicKit 전용 타이머 시작
        musicPlayerController.repeatMode = .none
        handlePlaybackStateChange() // 초기 상태 확인
    }

    // --- Protocol Conformance: Playback Control ---

    func play() async {
        print("AudioManager: play() called. isPlayingMusic: \(isPlayingMusic), isPlayingAI: \(isPlayingAIMusic)")
        if !isPlayingMusic {
            if isPlayingAIMusic {
                avPlayer?.play()
            } else {
                // MusicKit 재생 전에 AI 정리 (혹시 모를 상태 대비)
                if avPlayer != nil { cleanupAIPlayback() }
                musicPlayerController.play()
            }
            isPlayingMusic = true // @Published 업데이트 (UI 즉시 반영)
        }
    }

    // ✅ async 추가
    func pause() async {
        print("AudioManager: pause() called. isPlayingMusic: \(isPlayingMusic), isPlayingAI: \(isPlayingAIMusic)")
        if isPlayingMusic { // 재생 중일 때만 pause 의미 있음
            if isPlayingAIMusic {
                avPlayer?.pause()
            } else {
                musicPlayerController.pause()
            }
            isPlayingMusic = false // @Published 업데이트
        }
    }

    func stop() async {
        print("AudioManager: stop() called.")
        if isPlayingAIMusic {
            cleanupAIPlayback() // AI 재생 관련 정리
        } else {
            musicPlayerController.stop()
        }
        // 공통 초기화
        currentTime = 0
        duration = 0 // duration도 초기화
        isPlayingMusic = false
        isPlayingAIMusic = false // 확실히 초기화
        currentTrackMetadata = (nil, nil, nil) // 메타데이터 초기화
        // MusicKit 타이머는 계속 돌 수 있음 (선택적: stopTimerForMusicKit() 호출?)
    }

    func reset() async {
        print("AudioManager: reset() called.")
        await stop() // stop 로직 재사용
        avPlayer = nil // AVPlayer 완전 해제
        // currentTrackMetadata, duration, currentTime은 stop에서 이미 초기화됨
        removeAVPlayerObservers() // 옵저버 확실히 제거
    }

    // --- Protocol Conformance: Track Loading ---

    func playAppleMusicTrack(with title: String) async throws {
        print("AudioManager: playAppleMusicTrack(\(title)) called.")
        do {
            // 권한 및 구독 확인
            let authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else { throw PlayerError.musicAuthorizationFailed }
            let subscriptionStatus = try await MusicSubscription.current
            guard subscriptionStatus.canPlayCatalogContent else { throw PlayerError.noMusicSubscription }
            guard !title.isEmpty else { throw PlayerError.invalidTrackTitle }

            // AI 재생 중이면 명시적으로 정리
            if isPlayingAIMusic {
                print("   -> Cleaning up AI playback before playing Apple Music.")
                cleanupAIPlayback()
                // 상태 전환을 위한 짧은 지연 (선택적)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            }

            // MusicKit 검색
            var catalogSearchRequest = MusicCatalogSearchRequest(term: title, types: [MusicKit.Song.self])
            catalogSearchRequest.limit = 1
            let response = try await catalogSearchRequest.response()
            guard let song = response.songs.first else { throw PlayerError.trackNotFound(title) }

            // MusicKit 플레이어 재생 시작
            await playMusicWithPlayerController(song: song)
            isPlayingMusic = true // 재생 시작 시 상태 업데이트

        } catch {
            print("Error in playAppleMusicTrack: \(error)")
            // 여기서 에러 발생 시 재생 상태 업데이트 필요
            isPlayingMusic = false
            currentTrackMetadata = (nil, nil, nil) // 에러 시 메타데이터 초기화
            currentTime = 0
            duration = 0
            throw error // 에러 다시 던지기 (Reducer에서 처리하도록)
        }
    }

    func playAIMusic(from urlString: String) async {
        print("AudioManager: playAIMusic(\(urlString)) called.")

        // AI 재생 준비 전 MusicKit 상태 확인 및 중지
        if !isPlayingAIMusic && (musicPlayerController.playbackState == .playing) {
             print("   -> Pausing MusicKit player.")
             musicPlayerController.pause()
             // 상태 정리를 위한 약간의 지연 (선택적)
             try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        }

        // 기존 AVPlayer 정리 (중복 호출 방지 및 리소스 해제)
        cleanupAIPlayback() // 타이머/옵저버 제거 포함

        // 새 AVPlayer 설정
        guard let url = URL(string: urlString) else {
            print("   -> Invalid URL.")
            await handlePlaybackError(PlayerError.invalidURL(urlString))
            return
        }

        print("   -> Setting up AVPlayer for AI music: \(url.lastPathComponent)")

        // 메타데이터 미리 설정 (로딩 지연시에도 UI 업데이트)
        let filename = url.lastPathComponent
        currentTrackMetadata = (
            title: filename.components(separatedBy: ".").first ?? "AI Generated Music",
            artist: "AI Composer", // TODO: 실제 아티스트 정보 사용
            albumArt: nil // TODO: AI 노래 아트워크 로직?
        )

        // 플레이어 설정
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        avPlayer = AVPlayer(playerItem: playerItem)

        // 완료 알림 옵저버 설정
        avPlayerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main // 메인 큐 보장
        ) { [weak self] _ in
            self?.aiTrackDidFinish()
        }

        // 재생 준비 상태 체크 및 초기화
        currentTime = 0
        duration = 0 // 로드 후 설정됨

        // 플래그 설정 (순서 중요)
        isPlayingAIMusic = true
        isPlayingMusic = true // 통합 재생 상태 업데이트

        // 재생 시작
        avPlayer?.play()

        // AVPlayer 시간 관찰 시작
        startPeriodicTimeObserver()
        print("   -> AVPlayer setup and play initiated.")
    }

    // --- Protocol Conformance: State & Seeking ---

    func isPlaying() -> Bool {
        // isPlayingMusic @Published 프로퍼티가 타이머와 핸들러에서 관리되므로 이 값을 신뢰
        return self.isPlayingMusic
    }

    func seek(to seconds: Double) async {
        let targetTime = max(0, seconds)
        print("AudioManager: seek(to: \(targetTime)) called. isPlayingAI: \(isPlayingAIMusic)")

        if isPlayingAIMusic {
            guard let player = avPlayer, let item = player.currentItem,
                  item.status == .readyToPlay else {
                print("   -> Cannot seek: AI player not ready")
                return
            }
            // 정확한 seeking을 위해 timescale 지정
            let time = CMTime(seconds: targetTime, preferredTimescale: Int32(NSEC_PER_SEC))
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            // seek 완료 후 현재 시간 즉시 업데이트 (UI 반응성 개선)
            self.currentTime = targetTime
            print("   -> AI seek completed to: \(targetTime)")

        } else { // Apple Music
            if let itemDuration = musicPlayerController.nowPlayingItem?.playbackDuration, itemDuration > 0 {
                let boundedTime = min(targetTime, itemDuration)
                // MusicKit seek는 currentPlaybackTime 설정으로 수행
                musicPlayerController.currentPlaybackTime = boundedTime
                // seek 완료 후 현재 시간 즉시 업데이트
                self.currentTime = boundedTime
                print("   -> Apple Music seek to: \(boundedTime)")
            } else {
                 print("   -> Cannot seek: No Apple Music item or duration.")
            }
        }
    }

    // --- Internal Logic: Timers & Progress ---

    // MusicKit 플레이어 상태/시간 업데이트용 타이머
    private func startTimerForMusicKit() {
        print("AudioManager: Starting MusicKit timer.")
        timer?.invalidate() // 기존 타이머 중지
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // AI 음악 재생 중에는 이 타이머 로직 실행 안 함
            guard let self = self, !self.isPlayingAIMusic else { return }
            self.updateMusicKitPlaybackProgress()
        }
    }

    // MusicKit 재생 상태 및 시간 업데이트 (타이머에서 호출)
    private func updateMusicKitPlaybackProgress() {
        guard !isPlayingAIMusic else { return } // 방어 코드

        let currentState = musicPlayerController.playbackState
        let isNowPlaying = (currentState == .playing)

        // isPlayingMusic 상태 업데이트
        if isPlayingMusic != isNowPlaying {
            isPlayingMusic = isNowPlaying
        }

        // 재생 중일 때만 시간/기간 업데이트
        if isNowPlaying {
            let newTime = musicPlayerController.currentPlaybackTime
            if newTime.isFinite && newTime >= 0 {
                if abs(currentTime - newTime) > 0.1 {
                   currentTime = newTime
                }
            }

            let newDuration = musicPlayerController.nowPlayingItem?.playbackDuration ?? 0
            if newDuration.isFinite && newDuration > 0 {
                // Duration은 자주 바뀌지 않으므로 약간 다른 조건 사용 가능
                if duration != newDuration {
                    duration = newDuration
                }
            } else if duration != 0 {
                duration = 0 // 아이템이 없어지면 duration 0
            }

            checkForAppleMusicTrackCompletion() // 완료 체크
        }
        // 재생 중이 아닐 때 currentTime을 0으로 할지는 정책에 따라 결정 (일시정지 시 유지)
    }

    // AVPlayer 시간 업데이트용 관찰자 시작
    private func startPeriodicTimeObserver() {
        removePeriodicTimeObserver() // 기존 옵저버 제거
        guard let player = avPlayer else { return }

        print("   -> Starting periodic time observer for AVPlayer.")
        // 0.25초 간격으로 좀 더 부드럽게 업데이트
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: Int32(NSEC_PER_SEC)), queue: .main) { [weak self] time in
            guard let self = self, self.isPlayingAIMusic else { return } // AI 재생 중에만
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite && seconds >= 0 {
                 if abs(self.currentTime - seconds) > 0.05 { // 더 민감하게 업데이트
                     self.currentTime = seconds
                 }
                 // AI 음악 duration 업데이트 (AVPlayer 아이템 로드 완료 후)
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

    // AVPlayer 시간 관찰자 제거
    private func removePeriodicTimeObserver() {
        if let observer = timeObserver {
            print("   -> Removing periodic time observer.")
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }


    // --- Internal Logic: State Transitions & Cleanup ---

    // AI 재생 관련 리소스 정리
    private func cleanupAIPlayback() {
        print("AudioManager: cleanupAIPlayback() called.")
        removePeriodicTimeObserver() // 시간 관찰자 제거
        removeAVPlayerObservers() // 완료 알림 등 제거
        if let player = avPlayer {
            player.pause()
            player.replaceCurrentItem(with: nil) // 아이템 제거 중요!
        }
        avPlayer = nil // 플레이어 해제
        isPlayingAIMusic = false // 플래그 리셋
        // isPlayingMusic은 여기서 변경하지 않고, MusicKit/Reducer가 결정
    }

    // AVPlayer 관련 모든 알림 옵저버 제거
    private func removeAVPlayerObservers() {
         if let observer = avPlayerItemObserver {
             NotificationCenter.default.removeObserver(observer)
             avPlayerItemObserver = nil
             print("   -> Removed AVPlayerItem observer.")
         }
    }

    // AI 트랙 완료 처리 (NotificationCenter 콜백)
    private func aiTrackDidFinish() {
        print("AudioManager: aiTrackDidFinish called via Notification.")
        // isPlayingAIMusic 플래그가 true일 때만 처리 (중복 호출 방지)
        guard isPlayingAIMusic else { return }

        cleanupAIPlayback() // AI 관련 정리 수행

        // 재생 상태 업데이트 (@Published)
        isPlayingMusic = false
        currentTime = 0
        // duration = 0 // 필요시 초기화, 다음 곡 정보 로드시 덮어쓰여짐

        // 완료 알림 전송 -> Reducer가 다음 동작 결정
        print("   -> Posting audioDidFinishNotification.")
        NotificationCenter.default.post(name: AudioManager.audioDidFinishNotification, object: nil)
    }

    // --- Notification Handling ---

    private func setupNotifications() {
        // MusicKit 상태 변경 알림
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayerController,
            queue: .main
        ) { [weak self] _ in
             print("AudioManager: Received MPMusicPlayerControllerPlaybackStateDidChange.")
            self?.handlePlaybackStateChange()
        }
        musicPlayerController.beginGeneratingPlaybackNotifications()
    }

    // MusicKit 플레이어 상태 변경 처리
    private func handlePlaybackStateChange() {
        // AI 재생 중에는 MusicKit 상태 변경 무시 (충돌 방지)
        guard !isPlayingAIMusic else {
             print("   -> Ignoring MusicKit state change during AI playback.")
             return
        }

        let newState = musicPlayerController.playbackState
        let isNowPlaying = (newState == .playing)

        if isPlayingMusic != isNowPlaying {
             print("AudioManager: handlePlaybackStateChange - MusicKit state -> \(newState). Updating isPlayingMusic to \(isNowPlaying).")
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

        // 현재 아이템 가져오기
        let currentItem = musicPlayerController.nowPlayingItem

        // 메타데이터 업데이트 필요 여부 확인
        let needsMetadataUpdate = (currentTrackMetadata.title != currentItem?.title || currentTrackMetadata.artist != currentItem?.artist)

        if let item = currentItem { // 아이템이 있는 경우
            if needsMetadataUpdate {
                print("AudioManager: handleNowPlayingItemChange - New MusicKit item: \(item.title ?? "N/A")")
                currentTrackMetadata = (
                    title: item.title,
                    artist: item.artist,
                    albumArt: item.artwork?.image(at: CGSize(width: 300, height: 300)) // 필요한 크기로 조절
                )
                let newDuration = item.playbackDuration
                if newDuration.isFinite && newDuration > 0 {
                   duration = newDuration
                } else {
                   duration = 0 // 유효하지 않으면 0
                }
                currentTime = musicPlayerController.currentPlaybackTime // 아이템 변경 시 시간도 업데이트
            }
        } else { // 아이템이 없는 경우 (큐가 비었거나 초기 상태)
            if currentTrackMetadata.title != nil || currentTrackMetadata.artist != nil { // 이전에 정보가 있었다면 초기화
                 print("AudioManager: handleNowPlayingItemChange - MusicKit item cleared.")
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
             print("AudioManager: checkForAppleMusicTrackCompletion - Reached end of MusicKit track. Posting notification.")
             // 완료 알림을 한번만 보내도록 상태 관리 또는 타이머 중지 필요할 수 있음
             // 여기서는 알림만 보내고 Reducer가 처리하도록 함
             NotificationCenter.default.post(
                 name: AudioManager.audioDidFinishNotification,
                 object: nil
             )
             // TODO: 알림 보낸 후 즉시 isPlayingMusic=false로 할지, 아니면 audioDidFinish 액션 처리에 맡길지 결정
             // isPlayingMusic = false
        }
    }

    // --- Private Helpers ---

    @MainActor
    private func playMusicWithPlayerController(song: MusicKit.Song) async {
        print("   -> playMusicWithPlayerController called for \(song.title)")
        // 재생 시작 전 시간/기간 초기화
        self.currentTime = 0
        // Duration은 아이템 로드 시 설정되므로 0으로 초기화 불필요할 수 있으나, 명확성을 위해 추가 가능
        // self.duration = 0

        let storeID = song.id.rawValue
        if musicPlayerController.nowPlayingItem?.playbackStoreID != storeID {
             print("      -> Setting queue with \(storeID)")
             musicPlayerController.setQueue(with: [storeID])
             // setQueue 후 약간의 지연 필요할 수 있음
             // try? await Task.sleep(nanoseconds: 100_000_000)
             musicPlayerController.play()
        } else if musicPlayerController.playbackState != .playing {
             print("      -> Playing existing queue item \(storeID)")
             musicPlayerController.play()
        } else {
             print("      -> Already playing \(storeID).")
        }

        // 메타데이터 즉시 업데이트 시도 (실제 아이템 로드 시 handleNowPlayingItemChange에서도 업데이트됨)
        await updateTrackMetadata(song: song)
        // isPlayingMusic 상태 업데이트 (play 호출 후 시스템 상태 변경 알림이 약간 늦을 수 있으므로)
        self.isPlayingMusic = true
    }

    @MainActor
    private func updateTrackMetadata(song: MusicKit.Song) async {
         // 메타데이터 업데이트 (@Published 트리거)
         self.currentTrackMetadata = (title: song.title, artist: song.artistName, albumArt: nil)
         // 비동기로 앨범 아트 로드
         Task {
             if let artwork = song.artwork, let url = artwork.url(width: 300, height: 300) {
                 do {
                     let (data, _) = try await URLSession.shared.data(from: url)
                     // 메인 액터에서 @Published 프로퍼티 업데이트
                     self.currentTrackMetadata.albumArt = UIImage(data: data)
                 } catch {
                     print("      -> Failed to load artwork image: \(error)")
                     // 에러 발생 시 기본 이미지 설정 등 가능
                     // self.currentTrackMetadata.albumArt = nil // 이미 nil이므로 생략 가능
                 }
             }
         }
    }

    // 에러 처리 헬퍼 (예시)
    private func handlePlaybackError(_ error: Error) async {
         print("AudioManager: Handling playback error: \(error.localizedDescription)")
         // 상태 초기화
         isPlayingMusic = false
         if isPlayingAIMusic {
             cleanupAIPlayback()
         }
         // TODO: Reducer에 에러 전달하는 메커니즘 필요
         // 예를 들어, 에러 상태를 @Published로 만들거나 알림/Delegate 사용
         // NotificationCenter.default.post(name: playbackErrorNotification, object: error)
    }

    // --- Deinitialization ---
    deinit {
        print("AudioManager: deinit")
        timer?.invalidate() // MusicKit 타이머 중지
        musicPlayerController.endGeneratingPlaybackNotifications()
        if let observer = playbackStateObserver { NotificationCenter.default.removeObserver(observer) }
//        removeAVPlayerObservers() // AVPlayer 관련 옵저버 제거
//        removePeriodicTimeObserver()  AVPlayer 시간 옵저버 제거
        NotificationCenter.default.removeObserver(self) // 모든 알림 구독 해제
    }
}
