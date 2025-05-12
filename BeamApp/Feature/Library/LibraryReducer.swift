//
//  LibraryReducer.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import Foundation
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
                    return .send(.playlistFetchFailed("Invalid playlist ID"))
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
                state.errorMessage = nil
                return .send(.startPlayback(tracks))
                
            case let .startPlayback(tracks):
                guard let firstTrack = tracks.first else {
                    return .none
                }
                
                let trackTitle = firstTrack.title
                let trackStoreID = firstTrack.playbackStoreID
                
                print("LibraryReducer: Requesting startPlayback for track: \(trackTitle), StoreID: \(trackStoreID ?? "nil")")
                
                return .run { send in
                    do {
                        try await AudioManager.shared.playAppleMusicTrack(title: trackTitle, storeID: trackStoreID)
                        print("LibraryReducer: playAppleMusicTrack call potentially successful for \(trackTitle)")
                    } catch {
                        print("LibraryReducer Error: Failed to initiate playback for track '\(trackTitle)': \(error)")
                        await send(.playlistFetchFailed("Playback failed: \(error.localizedDescription)"))
                    }
                }
                
            case let .playlistFetchFailed(error):
                state.errorMessage = error
                return .none
            }
        }
    }
}

