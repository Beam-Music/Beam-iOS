import ComposableArchitecture
import Dispatch
import Foundation
import SwiftData
import UIKit

//TODO: background에서 다음 노래로 넘어가지 않는 이슈 해결 필요함

@Reducer
struct PlayerReducer {
    struct State: Equatable {
        var playlist: [PlayableTrackDTO] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false // 곡 전환(인덱스 변경) 중에만 true
        var isAIMusicEnabled: Bool = false // 토글 상태는 유지 (AI 곡 추가/제거 기준)
        var isLoadingAISongs: Bool = false
        var aiSongFetchError: String? = nil
        
        var currentTrack: PlayableTrackDTO? {
            guard !playlist.isEmpty, currentIndex >= 0, currentIndex < playlist.count else { return nil }
            return playlist[currentIndex]
        }
    }
    
    enum Action: Equatable {
        case syncPlaybackState
        case playPause
        case nextTrack
        case previousTrack
        case updateCurrentIndex(Int)
        case startPlayback // 현재 인덱스의 곡 재생 시작 요청
        case audioDidFinish // AudioManager로부터 재생 완료 알림 수신
        case playbackFinished // AudioManager에서 재생 준비/시작 완료됨
        case playbackError(String) // AudioManager에서 재생 오류 발생
        case toggleAIMusic(Bool)
        case fetchAISongs
        case aiSongsResponse(TaskResult<[PlayableTrackDTO]>)
        case removeAISongsFromPlaylist
        case aiPreferenceResponse(Result<Bool, Error>)
        case loadAIPreference
        case internalPlaybackStateResponse(Bool)
        case nextTrackResponse(TaskResult<PlayableTrackDTO>)
        
        static func == (lhs: PlayerReducer.Action, rhs: PlayerReducer.Action) -> Bool {
            switch (lhs, rhs) {
            case (.syncPlaybackState, .syncPlaybackState): return true
            case (.playPause, .playPause): return true
            case (.nextTrack, .nextTrack): return true
            case (.previousTrack, .previousTrack): return true
            case let (.updateCurrentIndex(l), .updateCurrentIndex(r)): return l == r
            case (.startPlayback, .startPlayback): return true
            case (.audioDidFinish, .audioDidFinish): return true
            case (.playbackFinished, .playbackFinished): return true
            case let (.playbackError(l), .playbackError(r)): return l == r
            case let (.toggleAIMusic(l), .toggleAIMusic(r)): return l == r
            case (.fetchAISongs, .fetchAISongs): return true
            case let (.aiSongsResponse(l), .aiSongsResponse(r)):
                switch (l, r) {
                case let (.success(lhsTracks), .success(rhsTracks)): return lhsTracks == rhsTracks
                case (.failure, .failure): return true
                default: return false
                }
            case (.removeAISongsFromPlaylist, .removeAISongsFromPlaylist): return true
            case let (.aiPreferenceResponse(.success(l)), .aiPreferenceResponse(.success(r))): return l == r
            case (.aiPreferenceResponse(.failure), .aiPreferenceResponse(.failure)): return true
            case (.loadAIPreference, .loadAIPreference): return true
            case let (.internalPlaybackStateResponse(l), .internalPlaybackStateResponse(r)): return l == r
            case let (.nextTrackResponse(l), .nextTrackResponse(r)):
                switch (l, r) {
                case let (.success(lhs), .success(rhs)): return lhs == rhs
                case (.failure, .failure): return true
                default: return false
                }
            default: return false
            }
        }
    }
    
    @Dependency(\.aiPreferenceClient) private var aiPreferenceClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.audioManager) var audioManager
    @Dependency(\.apiClient) var apiClient
    
    private func findNextTrackIndexSequentially(currentIndex: Int, playlistCount: Int) -> Int? {
        guard playlistCount > 0 else { return nil }
        return (currentIndex + 1) % playlistCount
    }
    
    private func findPreviousTrackIndexSequentially(currentIndex: Int, playlistCount: Int) -> Int? {
        guard playlistCount > 0 else { return nil }
        return (currentIndex - 1 + playlistCount) % playlistCount
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .syncPlaybackState:
                return .run { send in
                    let actualIsPlaying = await audioManager.isPlaying()
                    await send(.internalPlaybackStateResponse(actualIsPlaying))
                }
                
            case let .internalPlaybackStateResponse(actualIsPlaying):
                if state.isPlaying != actualIsPlaying {
                    state.isPlaying = actualIsPlaying
                }
                return .none
                
            case .playPause:
                let shouldPlay = !state.isPlaying
                state.isPlaying = shouldPlay
                return .run { [currentIndex = state.currentIndex, playlist = state.playlist] send in
                    if shouldPlay {
                        let didResume = await audioManager.tryResume()
                        if !didResume {
                            if currentIndex >= 0 && currentIndex < playlist.count {
                                await send(.startPlayback)
                            } else {
                                await send(.internalPlaybackStateResponse(false))
                            }
                        } else {
                            await send(.syncPlaybackState)
                        }
                    } else {
                        await audioManager.pause()
                        await send(.syncPlaybackState)
                    }
                }
                
            case .nextTrack:
                guard !state.playlist.isEmpty, !state.isTransitioning else { return .none }
                if let nextIndex = findNextTrackIndexSequentially(
                    currentIndex: state.currentIndex,
                    playlistCount: state.playlist.count
                ) {
                    return .send(.updateCurrentIndex(nextIndex))
                }
                return .none
                
            case .previousTrack:
                guard !state.playlist.isEmpty, !state.isTransitioning else { return .none }
                if let prevIndex = findPreviousTrackIndexSequentially(
                    currentIndex: state.currentIndex,
                    playlistCount: state.playlist.count
                ) {
                    return .send(.updateCurrentIndex(prevIndex))
                }
                return .none
                
            case let .updateCurrentIndex(index):
                guard !state.playlist.isEmpty,
                      index >= 0, index < state.playlist.count,
                      !state.isTransitioning
                else { return .none }
                
                if state.currentIndex == index {
                    if state.isPlaying {
                        return .none
                    } else {
                        return .send(.startPlayback)
                    }
                }
                
                state.isTransitioning = true
                state.currentIndex = index
                return .send(.startPlayback)
                
            case .audioDidFinish:
                // 이미 전환 중이면 무시
                guard !state.isTransitioning else {
                    print("PlayerReducer: AudioDidFinish received, but already transitioning. Ignoring.")
                    return .none
                }
                // 현재 트랙이 없으면 무시 (또는 정지)
                guard let currentTrack = state.currentTrack else {
                    print("PlayerReducer: AudioDidFinish received, but no current track.")
                    // 재생 중이었다면 멈추는 것이 더 자연스러울 수 있음
                    if state.isPlaying {
                        state.isPlaying = false
                        return .run { _ async in await audioManager.stop() } // 상태 변경과 Effect 동시 반환
                    }
                    return .none
                }
                
                print("PlayerReducer: AudioDidFinish for track \(currentTrack.title). Requesting next track from server.")
                state.isTransitioning = true // state 변경은 여기서 완료
                
                // --- FIX: Escaping 클로저에서 사용할 값을 미리 복사 ---
                let trackID = currentTrack.id
                let aiEnabled = state.isAIMusicEnabled // 값 복사
                // --- FIX END ---
                
                return .run { send in
                    // --- FIX: 복사된 상수 사용 ---
                    await send(.nextTrackResponse(
                        await TaskResult {
                            // apiClient.getNextTrack 호출 시 복사된 상수(trackID, aiEnabled) 사용
                            try await apiClient.getNextTrack(trackID, aiEnabled)
                        }
                    ))
                    // --- FIX END ---
                }
                
            case let .nextTrackResponse(.success(nextTrack)):
                print("PlayerReducer: Received next track from server: \(nextTrack.title)")
                if let nextIndex = state.playlist.firstIndex(where: { $0.id == nextTrack.id }) {
                    print("PlayerReducer: Found next track at index \(nextIndex)")
                    state.currentIndex = nextIndex
                    return .send(.startPlayback)
                } else {
                    print("PlayerReducer Error: Next track not found in playlist")
                    state.isTransitioning = false
                    state.isPlaying = false
                    return .send(.playbackError("Next track not found in playlist"))
                }
                
            case let .nextTrackResponse(.failure(error)):
                print("PlayerReducer Error: Failed to get next track: \(error)")
                state.isTransitioning = false
                state.isPlaying = false
                return .send(.playbackError("Failed to get next track"))
                
            case .startPlayback:
                guard let track = state.currentTrack else {
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { _ async in await audioManager.stop() }
                }
                
                state.isPlaying = true
                
                return .run { send async in
                    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
                    var taskIDForHandler = UIBackgroundTaskIdentifier.invalid
                    
                    backgroundTaskID = await UIApplication.shared.beginBackgroundTask {
                        print("⚠️ Background task expired for playback start. Task ID: \(taskIDForHandler)")
                        if taskIDForHandler != .invalid {
                            UIApplication.shared.endBackgroundTask(taskIDForHandler)
                        }
                    }
                    taskIDForHandler = backgroundTaskID
                    
                    print("Started background task: \(backgroundTaskID)")
                    
                    do {
                        if track.isAIGenerated {
                            guard let urlString = track.playbackUrl, !urlString.isEmpty else {
                                throw PlayerError.invalidURL("AI track URL missing or empty for track ID: \(track.id)")
                            }
                            print("PlayerReducer: Requesting AudioManager to play AI: \(track.title)")
                            try await audioManager.playAIMusic(from: urlString)
                        } else {
                            print("PlayerReducer: Requesting AudioManager to play MusicKit: \(track.title)")
                            try await audioManager.playAppleMusicTrack(title: track.title, storeID: track.playbackStoreID)
                        }
                        await send(.playbackFinished)
                    } catch {
                        print("PlayerReducer: Playback initiation failed for track '\(track.title)': \(error.localizedDescription)")
                        await send(.playbackError(error.localizedDescription))
                    }
                    
                    if backgroundTaskID != .invalid {
                        print("Ending background task: \(backgroundTaskID)")
                        await UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    }
                }
                
            case .playbackFinished:
                state.isTransitioning = false
                print("PlayerReducer: PlaybackFinished received, transition complete.")
                return .none
                
            case let .playbackError(errorString):
                print("PlayerReducer: Playback error received: \(errorString)")
                state.isTransitioning = false
                state.isPlaying = false
                return .run { _ async in await audioManager.stop() }
                
            case let .toggleAIMusic(isEnabled):
                if state.isAIMusicEnabled == isEnabled { return .none }
                
                state.isAIMusicEnabled = isEnabled
                state.aiSongFetchError = nil
                
                if isEnabled {
                    if !state.isLoadingAISongs && !state.playlist.contains(where: { $0.isAIGenerated }) {
                        return .send(.fetchAISongs)
                    }
                } else {
                    return .send(.removeAISongsFromPlaylist)
                }
                return .none
                
            case .fetchAISongs:
                guard state.isAIMusicEnabled, !state.isLoadingAISongs else { return .none }
                state.isLoadingAISongs = true
                state.aiSongFetchError = nil
                return .run { send in
                    await send(
                        .aiSongsResponse(
                            await TaskResult {
                                let token = try await HomeFeature.fetchToken(context: modelContext)
                                return try await HomeFeature.fetchPlayableAISongs(with: token)
                            }
                        )
                    )
                }
                
            case let .aiSongsResponse(.success(aiTracks)):
                state.isLoadingAISongs = false
                state.aiSongFetchError = nil
                let currentTrackIDs = Set(state.playlist.map { $0.id })
                let newAITracksToAdd = aiTracks.filter { !currentTrackIDs.contains($0.id) }
                if !newAITracksToAdd.isEmpty {
                    state.playlist.append(contentsOf: newAITracksToAdd)
                }
                return .none
                
            case let .aiSongsResponse(.failure(error)):
                state.isLoadingAISongs = false
                state.aiSongFetchError = error.localizedDescription
                return .none
                
            case .removeAISongsFromPlaylist:
                let originalPlaylist = state.playlist
                let originalIndex = state.currentIndex
                guard let trackBeingPlayed = state.currentTrack else {
                    state.playlist = []
                    state.currentIndex = 0
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { _ async in await audioManager.stop() }
                }
                
                let wasPlayingAITrack = trackBeingPlayed.isAIGenerated
                let wasPlaying = state.isPlaying
                let newPlaylist = originalPlaylist.filter { !$0.isAIGenerated }
                
                if newPlaylist.isEmpty {
                    state.playlist = []
                    state.currentIndex = 0
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { _ async in await audioManager.stop() }
                }
                
                var nextIndex = 0
                var shouldStartPlayback = false
                
                if wasPlayingAITrack {
                    state.isTransitioning = false
                    var nextOriginalNonAIIndex = -1
                    var searchIndex = (originalIndex + 1) % originalPlaylist.count
                    
                    for _ in 0..<originalPlaylist.count {
                        if !originalPlaylist[searchIndex].isAIGenerated {
                            nextOriginalNonAIIndex = searchIndex
                            break
                        }
                        searchIndex = (searchIndex + 1) % originalPlaylist.count
                    }
                    
                    if nextOriginalNonAIIndex != -1,
                       let foundTrack = originalPlaylist[safe: nextOriginalNonAIIndex],
                       let indexInNewList = newPlaylist.firstIndex(where: { $0.id == foundTrack.id }) {
                        nextIndex = indexInNewList
                        shouldStartPlayback = wasPlaying
                    } else {
                        nextIndex = 0
                        shouldStartPlayback = wasPlaying
                    }
                    print("Removed AI track. New index: \(nextIndex). Should start playback: \(shouldStartPlayback)")
                } else {
                    if let indexInNewList = newPlaylist.firstIndex(where: { $0.id == trackBeingPlayed.id }) {
                        nextIndex = indexInNewList
                        shouldStartPlayback = false
                        print("Kept MusicKit track. New index: \(nextIndex)")
                    } else {
                        print("Error: Playing MusicKit track not found after filtering AI songs. Resetting to index 0.")
                        nextIndex = 0
                        shouldStartPlayback = wasPlaying
                        state.isTransitioning = false
                    }
                }
                
                state.playlist = newPlaylist
                state.currentIndex = nextIndex
                
                if shouldStartPlayback {
                    state.isPlaying = true
                    return .send(.startPlayback)
                } else {
                    if !wasPlaying {
                        state.isPlaying = false
                    } else if !wasPlayingAITrack {
                        state.isPlaying = true
                    }
                    return .none
                }
                
            case .aiPreferenceResponse:
                return .none
                
            case .loadAIPreference:
                return .none
            }
        }
    }
}

//protocol AudioManagerProtocol {
//    func play() async
//    func pause() async
//    func stop() async
//    func playAppleMusicTrack(with title: String) async throws
//    func isPlaying() -> Bool
//    func seek(to seconds: Double) async
//    func reset() async
//    func playAIMusic(from urlString: String) async throws
//    var isAIPlaying: Bool { get }
//}
protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAppleMusicTrack(title: String?, storeID: String?) async throws
    func playAIMusic(from urlString: String) async throws
    func isPlaying() async -> Bool
    func tryResume() async -> Bool
    func seek(to seconds: Double) async
    var isAIPlaying: Bool { get }
}
private struct AudioManagerKey: DependencyKey {
    @MainActor
    static let liveValue: AudioManagerProtocol = AudioManager.shared }

extension DependencyValues {
    var audioManager: AudioManagerProtocol {
        get { self[AudioManagerKey.self] }
        set { self[AudioManagerKey.self] = newValue }
    }
}

struct APIClient {
    var getNextTrack: @Sendable (UUID, Bool) async throws -> PlayableTrackDTO
}

extension APIClient: DependencyKey {
    static let liveValue: APIClient = APIClient(
        getNextTrack: { currentTrackID, isAIMusicEnabled in
            var components = URLComponents(string: Endpoints.AISong.nextTrack)!
            components.queryItems = [
                URLQueryItem(name: "current_track_id", value: currentTrackID.uuidString),
                URLQueryItem(name: "is_ai_music_enabled", value: String(isAIMusicEnabled))
            ]
            
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.cannotParseResponse)
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(PlayableTrackDTO.self, from: data)
        }
    )
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

private struct APIClientKey: DependencyKey {
    static let liveValue: APIClient = APIClient.liveValue
} 
