//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture
import Dispatch

struct PlayerReducer: Reducer {
    struct State: Equatable {
        var playlist: [PlaylistTrack] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false
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
            default:
                return false
            }
        }
    }
    
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
//            todo : check
//            if !state.playlist.isEmpty {
//                state.isTransitioning = true
//                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
//                print("Reducer: Updated currentIndex to \(state.currentIndex), sending .startPlayback")
//                return .send(.startPlayback)
//            }
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
