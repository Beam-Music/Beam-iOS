import ComposableArchitecture
import Dispatch
import Foundation
import SwiftData

//TODO: background에서 다음 노래로 넘어가지 않는 이슈 해결 필요함
@Reducer
struct PlayerReducer {
    struct State: Equatable {
        var playlist: [PlayableTrackDTO] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false
        var isAIMusicEnabled: Bool = false
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
        case startPlayback
        case audioDidFinish
        case playbackFinished
        case playbackError(String)
        case toggleAIMusic(Bool)
        case fetchAISongs
        case aiSongsResponse(TaskResult<[PlayableTrackDTO]>)
        case removeAISongsFromPlaylist
        case aiPreferenceResponse(Result<Bool, Error>)
        case loadAIPreference
        
        static func == (lhs: PlayerReducer.Action, rhs: PlayerReducer.Action) -> Bool {
            switch (lhs, rhs) {
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
            default: return false
            }
        }
    }
    
    @Dependency(\.aiPreferenceClient) private var aiPreferenceClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.audioManager) var audioManager
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .syncPlaybackState:
                let actualIsPlaying = audioManager.isPlaying()
                if state.isPlaying != actualIsPlaying {
                    state.isPlaying = actualIsPlaying
                }
                return .none
            case .playPause:
                let shouldPlay = !state.isPlaying
                return .run { send in
                    if shouldPlay {
                        await send(.startPlayback)
                    } else {
                        await audioManager.pause()
                    }
                    try await Task.sleep(for: .milliseconds(200))
                    await send(.syncPlaybackState)
                }
                
            case .nextTrack:
                guard !state.isTransitioning, !state.playlist.isEmpty else { return .none }
                state.isTransitioning = true
                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
                return .send(.startPlayback)
                
            case .previousTrack:
                guard !state.isTransitioning, !state.playlist.isEmpty else { return .none }
                state.isTransitioning = true
                state.currentIndex = (state.currentIndex - 1 + state.playlist.count) % state.playlist.count
                return .send(.startPlayback)
                
            case let .updateCurrentIndex(index):
                guard !state.isTransitioning, !state.playlist.isEmpty,
                      index >= 0, index < state.playlist.count, state.currentIndex != index
                else { return .none }
                state.isTransitioning = true
                state.currentIndex = index
                return .send(.startPlayback)
                
            case .audioDidFinish:
                if !state.isTransitioning {
                    if state.currentIndex >= state.playlist.count - 1 {
                        state.currentIndex = 0
                        state.isPlaying = false
                        return .none
                    } else {
                        return .send(.nextTrack)
                    }
                }
                return .none
                
            case .startPlayback:
                guard let track = state.currentTrack else {
                    state.isPlaying = false
                    return .none
                }
                state.isPlaying = true
                
                return .run { send async in
                    do {
                        if track.isAIGenerated {
                            guard let urlString = track.playbackUrl, !urlString.isEmpty else {
                                throw NSError(domain: "PlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI track playback URL missing or empty."])
                            }
                            await AudioManager.shared.playAIMusic(from: urlString)
                            await send(.playbackFinished)
                        } else {
                            guard !track.title.isEmpty else {
                                throw NSError(domain: "PlayerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Apple Music track title missing."])
                            }
                            // --- 수정: playAppleMusicTrack 호출에 await 추가 ---
                            try await AudioManager.shared.playAppleMusicTrack(with: track.title) // <- await 추가!
                            // --- 수정 완료 ---
                            await send(.playbackFinished)
                        }
                    } catch {
                        print("Failed to initiate playback for track '\(track.title)': \(error)")
                        await send(.playbackError(error.localizedDescription))
                    }
                }
                
            case .playbackFinished:
                state.isTransitioning = false
                return .none
                
            case let .playbackError(errorString):
                print("Playback error received in reducer: \(errorString)")
                state.isTransitioning = false
                state.isPlaying = false
                return .none
                
            case let .toggleAIMusic(isEnabled):
                state.isAIMusicEnabled = isEnabled
                state.aiSongFetchError = nil
                let preferenceUpdateEffect: Effect<Action> = .run { send in /* ... (기존 코드 유지) ... */ }
                
                if isEnabled {
                    if !state.isLoadingAISongs && !state.playlist.contains(where: { $0.isAIGenerated }) {
                        return .merge(preferenceUpdateEffect, .send(.fetchAISongs))
                    } else {
                        return preferenceUpdateEffect
                    }
                } else {
                    return .merge(preferenceUpdateEffect, .send(.removeAISongsFromPlaylist))
                }
                
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
                let currentSongIDs = Set(state.playlist.map { $0.id })
                let newTracksToAdd = aiTracks.filter { !currentSongIDs.contains($0.id) }
                state.playlist.append(contentsOf: newTracksToAdd)
                return .none
                
            case let .aiSongsResponse(.failure(error)):
                state.isLoadingAISongs = false
                state.aiSongFetchError = error.localizedDescription
                return .none
                
            case .removeAISongsFromPlaylist:
                let originalCount = state.playlist.count
                state.playlist.removeAll { $0.isAIGenerated }
                let removedCount = originalCount - state.playlist.count
                if state.currentIndex >= state.playlist.count {
                    state.currentIndex = max(0, state.playlist.count - 1)
                    if state.playlist.isEmpty {
                        state.isPlaying = false
                    } else if state.isPlaying {
                        return .send(.startPlayback)
                    }
                }
                return .none
                
            case let .aiPreferenceResponse(.success(isEnabled)):
                return .none
            case let .aiPreferenceResponse(.failure(error)):
                return .none
            case .loadAIPreference:
                return .run { send in  }
            }
        }
    }
}

protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAppleMusicTrack(with title: String) async throws
    func playAIMusic(from urlString: String) async
    func isPlaying() -> Bool
    func seek(to seconds: Double) async
    func reset() async
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
