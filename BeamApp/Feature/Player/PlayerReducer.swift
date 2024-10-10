//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

// todo: playerview는 나중에 팝업 탭으로 바뀔꺼고 재생 목록도 지금처럼 첫번째 index의 playlist를 default playlist로 가져오는게 아니라 유저가 선택한 재생목록을 재생시켜야 하고 청취 기록 및 노래 추천 서비스도 추가되어야함
struct PlayerReducer: Reducer {
    struct State: Equatable {
        var playlist: [PlaylistTrack] = []
        var currentIndex: Int = 1
    }
    
    enum Action: Equatable {
        case playPause
        case nextTrack
        case previousTrack
        case updateCurrentIndex(Int)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .playPause:
            return .none
            
        case .nextTrack:
            if  !state.playlist.isEmpty {
                state.currentIndex = (state.currentIndex + 1) % state.playlist.count
            }
            return .none
            
        case .previousTrack:
            if !state.playlist.isEmpty {
                state.currentIndex = (state.currentIndex - 1 + state.playlist.count) % state.playlist.count
            }
            return .none
            
            
        case let .updateCurrentIndex(index):
            if !state.playlist.isEmpty && index >= 0 && index < state.playlist.count {
                state.currentIndex = index
            } else {
                state.currentIndex = 0
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
