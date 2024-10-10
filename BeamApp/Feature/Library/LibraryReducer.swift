//
//  LibraryReducer.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import ComposableArchitecture

struct LibraryReducer: Reducer {
    struct State: Equatable {
        var playlists: [UserPlaylist] = []
        var playlist: [PlaylistTrack] = []
        var errorMessage: String? = nil
    }
    
    enum Action: Equatable {
        case fetchUserPlaylists
        case userPlaylistsLoaded([UserPlaylist])
        case playlistFetchFailed(String)
    }
    
    @Dependency(\.modelContext) var modelContext
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchUserPlaylists:
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let playlists = try await HomeFeature.fetchUserPlaylists(with: token)
                        await send(.userPlaylistsLoaded(playlists))
                    } catch {
                        await send(.playlistFetchFailed(error.localizedDescription))
                    }
                }
                
            case let .userPlaylistsLoaded(playlists):
                state.playlists = playlists
                state.errorMessage = nil
                return .none
                
            case let .playlistFetchFailed(error):
                state.errorMessage = error 
                return .none
            }
        }
    }
}
