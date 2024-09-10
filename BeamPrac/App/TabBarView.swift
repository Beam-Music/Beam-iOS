//
//  TabBarView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct TabBarView: View {
    let store: StoreOf<AppReducer>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView {
                PlayerView(store: store.scope(
                    state: \.tabBarState.playerState,
                    action: { .tabBar(.player($0)) }
                ))
                .tabItem {
                    Label("Player", systemImage: "play.circle.fill")
                }
                
                GeneratorView(store: store.scope(
                    state: \.tabBarState.generatorState,
                    action: { .tabBar(.generator($0)) }
                ))
                .tabItem {
                    Label("Generator", systemImage: "waveform.path.ecg")
                }
            }
        }
    }
}

// Placeholder views for PlayerView and GeneratorView
struct PlayerView: View {
    let store: StoreOf<PlayerReducer>
    
    var body: some View {
        Text("Player View")
    }
}

struct GeneratorView: View {
    let store: StoreOf<GeneratorReducer>
    
    var body: some View {
        Text("Generator View")
    }
}

struct PlayerReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}

struct GeneratorReducer: Reducer {
    struct State: Equatable {}
    enum Action: Equatable {}
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        return .none
    }
}

