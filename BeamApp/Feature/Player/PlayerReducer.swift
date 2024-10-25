//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//
import Foundation
import ComposableArchitecture

struct PlayerReducer: Reducer {
    struct State: Equatable {
        var playlist: [PlaylistTrack] = []
        var originalPlaylist: [PlaylistTrack] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false
        var isAIMusicEnabled: Bool = false
    }
    
    enum Action: Equatable {
        case toggleAIMusic(Bool)
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
        case .toggleAIMusic(let isAIMusicEnabled):
            state.isAIMusicEnabled = isAIMusicEnabled
            if isAIMusicEnabled {
                let aiTracks = fetchAIMusicTracks()
                state.playlist = insertAIMusic(playlist: state.playlist, aiTracks: aiTracks)
            } else {
                state.playlist = state.originalPlaylist
            }
            return .none
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
    
    func fetchAIMusicTracks() -> [PlaylistTrack] {
        return [
            PlaylistTrack(id: UUID(), title: "AI Track 1", genre: "AI Genre", releaseDate: "2024-01-01", duration: 180),
            PlaylistTrack(id: UUID(), title: "AI Track 2", genre: "AI Genre", releaseDate: "2024-01-01", duration: 180),
            PlaylistTrack(id: UUID(), title: "AI Track 3", genre: "AI Genre", releaseDate: "2024-01-01", duration: 180)
        ]
    }

    func insertAIMusic(playlist: [PlaylistTrack], aiTracks: [PlaylistTrack], interval: Int = 2) -> [PlaylistTrack] {
        var updatedPlaylist = [PlaylistTrack]()
        var aiIndex = 0
        
        for (index, track) in playlist.enumerated() {
            updatedPlaylist.append(track)
            
            // Insert AI track after every 2-3 songs
            if (index + 1) % interval == 0, aiIndex < aiTracks.count {
                updatedPlaylist.append(aiTracks[aiIndex])
                aiIndex += 1
            }
        }
        return updatedPlaylist
    }
}

struct GeneratorReducer: Reducer {
    struct State: Equatable {
        var generatedMusic: String = ""
        var isTransitioning: Bool = false
        var isAIMusicEnabled: Bool = false
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
