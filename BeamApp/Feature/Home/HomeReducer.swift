//
//  HomeRouter.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import ComposableArchitecture
import SwiftData
import Foundation
import Dependencies

@Reducer
struct HomeReducer {
    struct State: Equatable {
        var route: Route?
        var listeningHistory: [ListeningHistoryItem] = []
        var errorMessage: String? = nil
        var playerState: PlayerReducer.State? = nil
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case logOutButtonTapped
        case setNavigation(Route?)
        case fetchListeningHistory
        case listeningHistoryLoaded([ListeningHistoryItem])
        case listeningHistoryFailed(String)
        case player(PlayerReducer.Action)
    }
    
    enum Route: Equatable {
        case detail
        case settings
        case player
    }
    
    @Dependency(\.modelContext) var modelContext
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .logOutButtonTapped:
                return .none
            case let .setNavigation(route):
                state.route = route
                if case .player = route {
                    state.playerState = PlayerReducer.State(                          listeningHistory: state.listeningHistory
                    )
                }
                return .none
                
            case let .setNavigation(route):
                state.route = route
                return .none
                
            case .fetchListeningHistory:
                return .run { [context = modelContext] send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: context)
                        let history = try await HomeFeature.fetchListeningHistory(with: token)
                        await send(.listeningHistoryLoaded(history))
                    } catch {
                        await send(.listeningHistoryFailed(error.localizedDescription))
                    }
                }
                
            case let .listeningHistoryLoaded(history):
                state.listeningHistory = history
                state.errorMessage = nil
                return .none
                
            case let .listeningHistoryFailed(error):
                state.errorMessage = error
                return .none
                
            case .player:
                return .none
            }
        }
        .ifLet(\.playerState, action: /HomeReducer.Action.player) {
            PlayerReducer() 
        }
    }
}

struct ModelContextKey: DependencyKey {
    @MainActor
    static let liveValue: ModelContext = {
        let container = try! ModelContainer(for: TokenEntity.self)
        return container.mainContext
    }()
}

extension DependencyValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
}
