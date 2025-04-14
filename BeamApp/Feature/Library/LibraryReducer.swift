//
//  LibraryReducer.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import ComposableArchitecture

struct LibraryReducer: Reducer {
    struct State: Equatable {
        var playlists: [PlaylistSummaryDTO] = []
        var playlist: [PlayableTrackDTO] = []
        var errorMessage: String? = nil
    }
    
    enum Action: Equatable {
        case fetchUserPlaylists
        case userPlaylistsLoaded([PlaylistSummaryDTO])
        case selectPlaylist(PlaylistSummaryDTO)
        case playlistLoaded([PlayableTrackDTO])
        case playlistFetchFailed(String)
        case startPlayback([PlayableTrackDTO])
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
                
            case let .selectPlaylist(playlist):
                guard let playlistID = playlist.id else {
                    return .none
                }
                let playlistIDString = playlistID.uuidString
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let tracks = try await HomeFeature.fetchPlaylist(with: token, playlistID: playlistIDString)
                        await send(.playlistLoaded(tracks))
                    } catch {
                        await send(.playlistFetchFailed(error.localizedDescription))
                    }
                }
                
            case let .playlistLoaded(tracks):
                state.playlist = tracks
                return .send(.startPlayback(tracks))
                
            case let .startPlayback(tracks):
                guard let firstTrack = tracks.first else {
                    return .none
                }
             
                return .run { [title = firstTrack.title] send async in
                    do {
                        try await AudioManager.shared.playAppleMusicTrack(with: title)
                    } catch {
                        print("Failed to initiate playback for track '\(title)': \(error)")
                    }
                }
                
            case let .playlistFetchFailed(error):
                state.errorMessage = error
                return .none
            }
        }
    }
}

