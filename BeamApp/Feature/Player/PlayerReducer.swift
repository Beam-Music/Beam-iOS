//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture
import Dispatch
import Foundation

struct PlayerReducer: Reducer {
    struct State: Equatable {
        var playlist: [PlaylistTrack] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false
        var isAIMusicEnabled: Bool = false
    }
    
    enum Action: Equatable {
        case playPause
        case nextTrack
        case previousTrack
        case updateCurrentIndex(Int)
        case startPlayback
        case audioDidFinish
        case playbackFinished
        case playbackError(Error)
        case toggleAIMusic(Bool)
        case aiPreferenceResponse(Result<Bool, Error>)
        case loadAIPreference

        static func == (lhs: PlayerReducer.Action, rhs: PlayerReducer.Action) -> Bool {
            switch (lhs, rhs) {
            case (.playPause, .playPause):
                return true
            case (.nextTrack, .nextTrack):
                return true
            case (.previousTrack, .previousTrack):
                return true
            case let (.updateCurrentIndex(lhsIndex), .updateCurrentIndex(rhsIndex)):
                return lhsIndex == rhsIndex
            case (.startPlayback, .startPlayback):
                return true
            case (.audioDidFinish, .audioDidFinish):
                return true
            case (.playbackFinished, .playbackFinished):
                return true
            case let (.playbackError(lhsError), .playbackError(rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            case let (.toggleAIMusic(lhsEnabled), .toggleAIMusic(rhsEnabled)):
                return lhsEnabled == rhsEnabled
            case (.aiPreferenceResponse(.success(let lhsEnabled)), .aiPreferenceResponse(.success(let rhsEnabled))):
                return lhsEnabled == rhsEnabled
            case (.aiPreferenceResponse(.failure), .aiPreferenceResponse(.failure)):
                return true // Simplify for Equatable
            case (.loadAIPreference, .loadAIPreference):
                return true
            default:
                return false
            }
        }
    }
    
    @Dependency(\.aiPreferenceClient) private var aiPreferenceClient
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .playPause:
            state.isPlaying.toggle()
            if state.isPlaying {
                return .send(.startPlayback)
            } else {
                AudioManager.shared.pause()
            }
            return .none
            
        case .nextTrack:
            guard !state.isTransitioning else {
                return .none
            }
            if !state.playlist.isEmpty {
                state.isTransitioning = true
                let oldIndex = state.currentIndex
                let newIndex = (oldIndex + 1) % state.playlist.count
                state.currentIndex = newIndex
                return .send(.startPlayback)
            }
            return .none
            
        case .previousTrack:
            guard !state.isTransitioning else {
                return .none
            }
            
            if !state.playlist.isEmpty {
                state.isTransitioning = true
                state.currentIndex = (state.currentIndex - 1 + state.playlist.count) % state.playlist.count
                return .send(.startPlayback)
            }
            return .none
            
        case let .updateCurrentIndex(index):
            guard !state.isTransitioning else {
                return .none
            }
            
            if !state.playlist.isEmpty && index >= 0 && index < state.playlist.count {
                state.isTransitioning = true
                state.currentIndex = index
                return .send(.startPlayback)
            }
            return .none
            
        case .audioDidFinish:
            if state.currentIndex >= state.playlist.count - 1 {
                return .send(.updateCurrentIndex(0))
            } else {
                return .send(.nextTrack)
            }
            
        case .startPlayback:
            guard !state.playlist.isEmpty,
                  state.currentIndex >= 0 && state.currentIndex < state.playlist.count else { return .none }
            let currentTrack = state.playlist[state.currentIndex]
            state.isPlaying = true
            
            return .run { [title = currentTrack.title] send async in
                do {
                    try await AudioManager.shared.playAppleMusicTrack(with: title)
                    await send(.playbackFinished)
                    
                } catch {
                    await send(.playbackError(error))
                }
            }

        case .playbackFinished:
            state.isTransitioning = false
            return .none

        case let .playbackError(error):
            print("Playback error received: \(error)")
            state.isTransitioning = false
            state.isPlaying = false
            return .none
            
        case let .toggleAIMusic(isEnabled):
            state.isAIMusicEnabled = isEnabled
            
            return .run { send in
                do {
                    // --- 임시 수정 시작 ---
                    // UserDefaults에서 가져오는 대신 테스트 ID를 직접 사용
                    let userIdString = "7d634b64-551f-479f-8fe9-9868e9d1a5fe"
                    guard let userUUID = UUID(uuidString: userIdString) else {
                        // 이 경우는 ID 형식이 잘못되었을 때만 발생 (지금은 고정값이므로 거의 발생 안 함)
                        throw NSError(domain: "BeamApp", code: 400,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid Hardcoded User ID Format"])
                    }
                    // --- 임시 수정 끝 ---
                    
                    /* 원래 코드 주석 처리
                     guard let userId = UserDefaults.standard.string(forKey: "userId"),
                     let userUUID = UUID(uuidString: userId) else {
                     throw NSError(domain: "BeamApp", code: 400,
                     userInfo: [NSLocalizedDescriptionKey: "User ID not found"])
                     }
                     */
                    
                    print("Attempting to update AI preference for fixed test user: \(userUUID)") // 디버깅 로그 추가
                    
                    let result = try await aiPreferenceClient.updateAIPreference(userUUID, isEnabled)
                    await send(.aiPreferenceResponse(.success(result)))
                    
                } catch {
                    print("Error during AI preference update: \(error)") // 에러 로그 추가
                    await send(.aiPreferenceResponse(.failure(error)))
                    // 실패 시 롤백하는 로직은 그대로 둡니다.
                    await send(.toggleAIMusic(!isEnabled))
                }
            }
            
        case let .aiPreferenceResponse(.success(isEnabled)):
            state.isAIMusicEnabled = isEnabled
            return .none
            
        case let .aiPreferenceResponse(.failure(error)):
            print("Failed to update AI preference: \(error.localizedDescription)")
            // Could add an alert here
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
                    // Silently fail on initial load
                }
            }
        }
    }
}

struct GeneratorReducer: Reducer {
    struct State: Equatable {
        var generatedMusic: String = ""
    }
    
    enum Action: Equatable {
        case generateNewMusic
        case stopGeneration
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .generateNewMusic:
            state.generatedMusic = "New Music Generated"
            return .none
            
        case .stopGeneration:
            state.generatedMusic = ""
            return .none
        }
    }
}
