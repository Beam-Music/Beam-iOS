import ComposableArchitecture
import Dispatch
import Foundation
import SwiftData

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
            guard !playlist.isEmpty, currentIndex >= 0, currentIndex < playlist.count else {
                return nil
            }
            return playlist[currentIndex]
        }
    }
    
    enum Action: Equatable {
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
                case let (.success(lhsTracks), .success(rhsTracks)):
                    return lhsTracks == rhsTracks
                case (.failure, .failure):
                    return true
                default:
                    return false
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
    
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .playPause:
                state.isPlaying.toggle()
                if state.isPlaying {
                    if state.currentTrack != nil { return .send(.startPlayback) }
                    else { state.isPlaying = false }
                } else {
                    AudioManager.shared.pause()
                }
                return .none
                
            case .nextTrack:
                guard !state.isTransitioning, !state.playlist.isEmpty else { return .none }
                state.isTransitioning = true
                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
                return .send(.startPlayback)
                
            case .previousTrack:
                guard !state.isTransitioning, !state.playlist.isEmpty else { return .none }
                let currentTime = AudioManager.shared.getCurrentTime()
                if currentTime < 5 {
                    state.isTransitioning = true
                    state.currentIndex = (state.currentIndex - 1 + state.playlist.count) % state.playlist.count
                } else {
                    state.isTransitioning = true
                    AudioManager.shared.seek(to: 0)
                    return .run { send async in
                        try? await Task.sleep(for: .milliseconds(100))
                        await send(.playbackFinished) // Seek 완료 가정
                    }
                }
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
                            AudioManager.shared.playAIMusic(from: urlString)
                            await send(.playbackFinished)
                        } else {
                            guard !track.title.isEmpty else {
                                throw NSError(domain: "PlayerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Apple Music track title missing."])
                            }
                            try await AudioManager.shared.playAppleMusicTrack(with: track.title)
                            await send(.playbackFinished)
                        }
                    } catch {
                        await send(.playbackError(error.localizedDescription))
                    }
                }
                
            case .playbackFinished:
                state.isTransitioning = false
                return .none
                
            case let .playbackError(errorString):
                state.isTransitioning = false
                state.isPlaying = false
                return .none
                
            case let .toggleAIMusic(isEnabled):
                state.isAIMusicEnabled = isEnabled
                state.aiSongFetchError = nil
                
                let preferenceUpdateEffect: Effect<Action> = .run { send in
                    do {
                        let userIdString = "7D634B64-551F-479F-8FE9-9868E9D1A5FE" // TODO: 테스트용 ID,  수정 필요함
                        guard let userUUID = UUID(uuidString: userIdString) else { throw URLError(.badURL) }
                        let result = try await aiPreferenceClient.updateAIPreference(userUUID, isEnabled)
                    } catch {
                        await send(.aiPreferenceResponse(.failure(error)))
                        await send(.toggleAIMusic(!isEnabled)) // UI 상태만 되돌림
                    }
                }
                
                if isEnabled {
                    if !state.isLoadingAISongs && !state.playlist.contains(where: { $0.isAIGenerated }) {
                        return .merge(
                            preferenceUpdateEffect,
                            .send(.fetchAISongs)
                        )
                    } else {
                        return preferenceUpdateEffect
                    }
                } else {
                    return .merge(
                        preferenceUpdateEffect,
                        .send(.removeAISongsFromPlaylist)
                    )
                }
            case .fetchAISongs:
                guard !state.isLoadingAISongs else { return .none }
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
                return .run { send in
                    do {
                        guard let userId = UserDefaults.standard.string(forKey: "userId"),
                              let userUUID = UUID(uuidString: userId) else {
                            return
                        }
                        let isEnabled = try await aiPreferenceClient.getAIPreference(userUUID)
                        await send(.aiPreferenceResponse(.success(isEnabled)))
                    } catch {
                        print("Failed to load AI preference: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
