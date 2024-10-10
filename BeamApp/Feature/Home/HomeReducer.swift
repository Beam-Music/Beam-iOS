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
        var playlist: [PlaylistTrack] = []
        var errorMessage: String? = nil
        var playerState: PlayerReducer.State? = nil
        var selectedPlaylistID: String? = nil
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case logOutButtonTapped
        case setNavigation(Route?)
        case fetchPlaylist(String)
        case fetchUserPlaylists
        case userPlaylistsLoaded([UserPlaylist])
        case playlistLoaded([PlaylistTrack])
        case playlistFailed(String)
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
                    state.playerState = PlayerReducer.State(
                        playlist: state.playlist,
                        currentIndex: 0
                    )
                }
                return .none
                
            case .fetchUserPlaylists:
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let userPlaylists = try await HomeFeature.fetchUserPlaylists(with: token)
                        await send(.userPlaylistsLoaded(userPlaylists))
                    } catch {
                        await send(.playlistFailed(error.localizedDescription))
                    }
                }
                
            case let .userPlaylistsLoaded(userPlaylists):
                if let firstPlaylist = userPlaylists.first {
                    state.selectedPlaylistID = firstPlaylist.id
                    return .send(.fetchPlaylist(firstPlaylist.id))
                }
                return .none
                
            case .fetchPlaylist:
                guard let playlistID = state.selectedPlaylistID else {
                    return .none
                }
                return .run { [context = modelContext] send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: context)
                        let playlist = try await HomeFeature.fetchPlaylist(with: token, playlistID: playlistID)
                        await send(.playlistLoaded(playlist))
                    } catch {
                        await send(.playlistFailed(error.localizedDescription))
                    }
                }
                
                
            case let .playlistLoaded(playlist):
                state.playlist = playlist
                state.errorMessage = nil
                if !playlist.isEmpty {
                        state.route = .player
                }
                return .none
                
            case let .playlistFailed(error):
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
