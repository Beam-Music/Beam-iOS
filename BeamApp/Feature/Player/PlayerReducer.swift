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

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .playPause:
                state.isPlaying.toggle()
                if state.isPlaying {
                    if state.currentTrack != nil { return .send(.startPlayback) }
                    else { state.isPlaying = false; return .none }
                } else {
                    return .run { _ in await AudioManager.shared.pause() }
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
                    print("Playback Error: Current track is nil.")
                    state.isPlaying = false
                    return .none
                }
                state.isPlaying = true // UI 상 재생 상태 우선 반영

                return .run { send async in
                    do {
                        if track.isAIGenerated {
                            guard let urlString = track.playbackUrl, !urlString.isEmpty else {
                                throw NSError(domain: "PlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI track playback URL missing or empty."])
                            }
                            // playAIMusic은 @MainActor이지만 동기 함수이므로 await 없음
                            await AudioManager.shared.playAIMusic(from: urlString) // @MainActor 함수 호출 (await 필요)
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
                  print("Added \(newTracksToAdd.count) AI songs to the playlist.")
                  return .none

             case let .aiSongsResponse(.failure(error)):
                  state.isLoadingAISongs = false
                  state.aiSongFetchError = error.localizedDescription
                  print("Failed to fetch AI songs: \(error)")
                  return .none

             case .removeAISongsFromPlaylist:
                  let originalCount = state.playlist.count
                  state.playlist.removeAll { $0.isAIGenerated }
                  let removedCount = originalCount - state.playlist.count
                  print("Removed \(removedCount) AI songs from the playlist.")
                  if state.currentIndex >= state.playlist.count {
                      state.currentIndex = max(0, state.playlist.count - 1)
                      if state.playlist.isEmpty {
                          state.isPlaying = false
                      } else if state.isPlaying {
                           return .send(.startPlayback)
                      }
                  }
                  return .none

            // AI 선호도 관련 케이스들 ... (기존 코드 유지) ...
            case let .aiPreferenceResponse(.success(isEnabled)):
                 // state.isAIMusicEnabled = isEnabled // 이미 처리됨
                 print("AI preference successfully updated to \(isEnabled) on server.")
                 return .none
            case let .aiPreferenceResponse(.failure(error)):
                 print("Reducer received AI preference update failure: \(error.localizedDescription)")
                 return .none
            case .loadAIPreference:
                  return .run { send in /* ... (기존 코드 유지) ... */ }
            }
        }
    }
}
