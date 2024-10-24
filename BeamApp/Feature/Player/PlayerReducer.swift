//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct PlayerReducer: Reducer {
    struct State: Equatable {
        var playlist: [PlaylistTrack] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
    }
    
    enum Action: Equatable {
        case playPause
        case nextTrack
        case previousTrack
        case updateCurrentIndex(Int)
        case startPlayback
        case audioDidFinish
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .playPause:
            state.isPlaying.toggle()
            return .none
            
        case .nextTrack:
            if !state.playlist.isEmpty {
                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
                return .send(.startPlayback)
            }
            return .none
            
        case .previousTrack:
            if !state.playlist.isEmpty {
                state.currentIndex = (state.currentIndex - 1 + state.playlist.count) % state.playlist.count
                return .send(.startPlayback)
            }
            return .none
            
        case let .updateCurrentIndex(index):
            if !state.playlist.isEmpty && index >= 0 && index < state.playlist.count {
                state.currentIndex = index
                return .send(.startPlayback)
            }
            return .none
            
        case .audioDidFinish:
            if !state.playlist.isEmpty && state.currentIndex < state.playlist.count - 1 {
                let nextIndex = state.currentIndex + 1
                let nextTrack = state.playlist[nextIndex]
                state.currentIndex = nextIndex
                
                return .run { send in
                    try await Task.sleep(for: .seconds(1))
                    await send(.startPlayback)
                }
            }
            return .none
          
        case .startPlayback:
            if !state.playlist.isEmpty {
                let currentTrack = state.playlist[state.currentIndex]
                let hasNextTrack = state.currentIndex < state.playlist.count - 1
                let nextTrackTitle = hasNextTrack ? state.playlist[state.currentIndex + 1].title : nil
                
                state.isPlaying = true
                
                return .run { _ in
                    await AudioManager.shared.playAppleMusicTrack(with: currentTrack.title)
                    
                    if hasNextTrack, let nextTitle = nextTrackTitle {
                        await AudioManager.shared.queueNextTrack(trackTitle: nextTitle)
                    }
                }
            }
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
