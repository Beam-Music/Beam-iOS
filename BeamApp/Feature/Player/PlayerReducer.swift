//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/12/24.
//

import ComposableArchitecture

struct PlayerReducer: Reducer {
    struct State: Equatable {
        var listeningHistory: [ListeningHistoryItem] = []
        var currentIndex: Int = 0
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
            if !state.listeningHistory.isEmpty {
                state.currentIndex = (state.currentIndex + 1) % state.listeningHistory.count
                print("Next Track: Current Index is \(state.currentIndex)")
                
            }
            return .none
            
        case .previousTrack:
            if !state.listeningHistory.isEmpty {
                state.currentIndex = (state.currentIndex - 1 + state.listeningHistory.count) % state.listeningHistory.count
                print("previousTrack: Current Index is \(state.currentIndex)")
                
            }
            return .none
            
            
        case let .updateCurrentIndex(index):
            if !state.listeningHistory.isEmpty && index >= 0 && index < state.listeningHistory.count {
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
