//
//  LibraryReducer.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import Foundation
import ComposableArchitecture

struct LibraryReducer: Reducer {
    @ObservableState
    struct State: Equatable {
        var playlists: [PlaylistSummaryDTO] = []
        var playlist: [PlayableTrackDTO] = []
        var errorMessage: String? = nil
        var isPresentingCreateSheet: Bool = false
        var newPlaylistName: String = ""
        var isCreatingPlaylist: Bool = false
        var selectedPlaylist: PlaylistSummaryDTO? = nil
        var selectedPlaylistSongs: [PlayableTrackDTO] = []
        var selectedPlaylistSongsVersion: Int = 0
        var isShowingDetail: Bool = false
        var isAddingSong: Bool = false
    }
    
    enum Action: Equatable {
        case fetchUserPlaylists
        case userPlaylistsLoaded([PlaylistSummaryDTO])
        case selectPlaylist(PlaylistSummaryDTO)
        case playlistLoaded([PlayableTrackDTO])
        case playlistFetchFailed(String)
        case startPlayback([PlayableTrackDTO])
        case showCreatePlaylistSheet(Bool)
        case updateNewPlaylistName(String)
        case createPlaylist
        case playlistCreated(PlaylistSummaryDTO)
        case playlistCreateFailed(String)
        case showPlaylistDetail(Bool)
        case fetchPlaylistSongs(PlaylistSummaryDTO)
        case playlistSongsLoaded([PlayableTrackDTO])
        case addSongToPlaylist
        case songAddedToPlaylist
        case playAllInPlaylist
        case deletePlaylist(IndexSet)
        case playlistDeleted(UUID)
        case playlistDeleteFailed(String)
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
                state.selectedPlaylist = playlist
                state.isShowingDetail = true
                state.selectedPlaylistSongs = []
                return .send(.fetchPlaylistSongs(playlist))
                
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
            case .showCreatePlaylistSheet(let show):
                state.isPresentingCreateSheet = show
                if !show {
                    state.newPlaylistName = ""
                }
                return .none
            case .updateNewPlaylistName(let name):
                state.newPlaylistName = name
                return .none
            case .createPlaylist:
                guard !state.newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty else {
                    state.errorMessage = "플레이리스트 이름을 입력하세요."
                    return .none
                }
                state.isCreatingPlaylist = true
                let playlistName = state.newPlaylistName
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let playlist = try await HomeFeature.createUserPlaylist(with: token, name: playlistName)
                        await send(.playlistCreated(playlist))
                    } catch {
                        await send(.playlistCreateFailed(error.localizedDescription))
                    }
                }
            case let .playlistCreated(playlist):
                state.isCreatingPlaylist = false
                state.isPresentingCreateSheet = false
                state.newPlaylistName = ""
                state.playlists.insert(playlist, at: 0)
                state.errorMessage = nil
                return .none
            case let .playlistCreateFailed(error):
                state.isCreatingPlaylist = false
                state.errorMessage = error
                return .none
            case .showPlaylistDetail(let show):
                state.isShowingDetail = show
                if !show {
                    state.selectedPlaylist = nil
                    state.selectedPlaylistSongs = []
                }
                return .none
            case .fetchPlaylistSongs(let playlist):
                guard let playlistID = playlist.id else {
                    return .send(.playlistFetchFailed("Invalid playlist ID"))
                }
                let playlistIDString = playlistID.uuidString
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let tracks = try await HomeFeature.fetchPlaylist(with: token, playlistID: playlistIDString)
                        await send(.playlistSongsLoaded(tracks))
                    } catch {
                        await send(.playlistFetchFailed(error.localizedDescription))
                    }
                }
            case .playlistSongsLoaded(let tracks):
                state.selectedPlaylistSongs = Array(tracks)
                state.selectedPlaylistSongsVersion += 1
                state.errorMessage = nil
                return .none
            case .addSongToPlaylist:
                state.isAddingSong = true
                return .none
            case .songAddedToPlaylist:
                state.isAddingSong = false
                if let playlist = state.selectedPlaylist {
                    return .send(.fetchPlaylistSongs(playlist))
                }
                return .none
            case .playAllInPlaylist:
                guard !state.selectedPlaylistSongs.isEmpty else { return .none }
                return .send(.startPlayback(state.selectedPlaylistSongs))
            case let .deletePlaylist(indexSet):
                guard let index = indexSet.first, state.playlists.indices.contains(index) else { return .none }
                let playlist = state.playlists[index]
                guard let playlistID = playlist.id else { return .none }
                return .run { send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let urlString = Endpoints.Playlist.userPlaylist + "/\(playlistID.uuidString)"
                        var request = URLRequest(url: URL(string: urlString)!)
                        request.httpMethod = "DELETE"
                        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        let (_, response) = try await URLSession.shared.data(for: request)
                        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                            await send(.playlistDeleteFailed("플레이리스트 삭제에 실패했습니다."))
                            return
                        }
                        await send(.playlistDeleted(playlistID))
                    } catch {
                        await send(.playlistDeleteFailed(error.localizedDescription))
                    }
                }
            case let .playlistDeleted(playlistID):
                state.playlists.removeAll { $0.id == playlistID }
                state.errorMessage = nil
                return .none
            case let .playlistDeleteFailed(error):
                state.errorMessage = error
                return .none
            }
        }
    }
}

