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
            
            if !state.playlist.isEmpty {
                state.isTransitioning = true
                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
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
            guard !state.playlist.isEmpty else { return .none }
            
            let currentTrack = state.playlist[state.currentIndex]
            let nextTrackTitle = state.currentIndex < state.playlist.count - 1 ? state.playlist[state.currentIndex + 1].title : nil
            state.isPlaying = true
            
            return .run { send in
                await AudioManager.shared.playAppleMusicTrack(with: currentTrack.title)
                
                if let nextTrackTitle = nextTrackTitle {
                    await AudioManager.shared.queueNextTrack(trackTitle: nextTrackTitle)
                }
                
                await send(.playbackFinished)
            }
            
        case .playbackFinished:
            state.isTransitioning = false
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
