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
            // 마지막 곡일 경우 지금은 리스트의 첫 번째 곡으로 돌아가기 나중에 random recommend playlist로 더 듣게하기
            if state.currentIndex >= state.playlist.count - 1 {
                return .send(.updateCurrentIndex(0))
            } else {
                return .send(.nextTrack)
            }
            
        case .startPlayback:
            if !state.playlist.isEmpty {
                let currentTrack = state.playlist[state.currentIndex]
                let nextTrackTitle = state.currentIndex < state.playlist.count - 1 ? state.playlist[state.currentIndex + 1].title : nil
                state.isPlaying = true
                
                return .run { send in
                    await AudioManager.shared.playAppleMusicTrack(with: currentTrack.title)
                    
                    if let nextTrackTitle = nextTrackTitle {
                        await AudioManager.shared.queueNextTrack(trackTitle: nextTrackTitle)
                    }
                    
                    //                            await send(.playbackStarted)
                }
            }
            return .none
            
            
            //                case .playbackStarted:
            //                    // 상태 업데이트가 필요하다면 여기에서 처리
            //                    return .none
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
