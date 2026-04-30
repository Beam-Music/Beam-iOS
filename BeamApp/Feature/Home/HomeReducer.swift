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
        var searchText: String = ""
        var searchResults: [MusicSearchResult] = []
        var playlists: [PlaylistSummaryDTO] = []
        var isSearching: Bool = false
        var error: String? = nil
        var route: Route?
        var playlist: [PlayableTrackDTO] = []
        var errorMessage: String? = nil
        var selectedPlaylistID: String? = nil
        var recommendedPlaylists: [PlaylistSummaryDTO] = []
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case searchTextChanged(String)
        case clearSearchResults
        case playMusic(MusicSearchResult)
        case playlistSelected(PlaylistSummaryDTO)
        case searchResponseSuccess([MusicSearchResult])
        case searchResponseFailure(String)
        case logOutButtonTapped
        case setNavigation(Route?)
        case fetchPlaylist(String)
        case fetchUserPlaylists
        case userPlaylistsLoaded([PlaylistSummaryDTO])
        case playlistLoaded([PlayableTrackDTO])
        case playlistFailed(String)
        case player(PlayerReducer.Action)
        case fetchRecommendPlaylists
        case recommendPlaylistsLoaded([PlaylistSummaryDTO])
        case recommendPlaylistsFailed(String)
        case fetchRecommendPlaylistSongs(String)
        case startPlayback([PlayableTrackDTO])
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
            case .searchTextChanged(let text):
                state.searchText = text
                state.isSearching = !text.isEmpty
                if !text.isEmpty {
                    return .run { send in
                        let service = MusicSearchService()
                        do {
                            let results = try await service.searchMusic(query: text)
                            await send(.searchResponseSuccess(results))
                        } catch {
                            await send(.searchResponseFailure(error.localizedDescription))
                        }
                    }
                } else {
                    state.searchResults = []
                    return .none
                }
            case .clearSearchResults:
                state.searchText = ""
                state.searchResults = []
                state.isSearching = false
                return .none
            case .playMusic(let result):
                let track = PlayableTrackDTO(
                    id: UUID(),
                    title: result.title,
                    artistName: result.artist,
                    playbackUrl: nil,
                    playbackStoreID: result.id,
                    isAIGenerated: false,
                    duration: nil,
                    fileUrl: nil,
                    artworkURL: result.artworkURL
                )
                state.route = .player
                return .none
            case .playlistSelected(let playlist):
                guard let playlistID = playlist.id else {
                    return .none
                }
                let playlistIDString = playlistID.uuidString
                state.selectedPlaylistID = playlistIDString
                return .send(.fetchRecommendPlaylistSongs(playlistIDString))
            case .searchResponseSuccess(let results):
                state.searchResults = results
                state.isSearching = false
                state.error = nil
                return .none
            case .searchResponseFailure(let error):
                state.error = error
                state.isSearching = false
                return .none
            case .binding:
                return .none
            case .logOutButtonTapped:
                return .none
            case let .setNavigation(route):
                state.route = route
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
                state.playlists = userPlaylists
                if let firstPlaylist = userPlaylists.first, let playlistID = firstPlaylist.id {
                    let playlistIDString = playlistID.uuidString
                    state.selectedPlaylistID = playlistIDString
                    return .send(.fetchPlaylist(playlistIDString))
                }
                return .none
            case .fetchPlaylist(let playlistID):
                return .run { [context = modelContext] send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: context)
                        let playlist = try await HomeFeature.fetchPlaylist(with: token, playlistID: playlistID)
                        await send(.playlistLoaded(playlist))
                    } catch {
                        await send(.playlistFailed(error.localizedDescription))
                    }
                }
            case .fetchRecommendPlaylists:
                return .run { send in
                    do {
                        let recommendPlaylists = try await HomeFeature.fetchRecommendPlaylists()
                        await send(.recommendPlaylistsLoaded(recommendPlaylists))
                    } catch let error as APIError {
                        switch error {
                        case .serverError(404, _):
                            await send(.recommendPlaylistsLoaded([]))
                        default:
                            await send(.recommendPlaylistsFailed(error.localizedDescription))
                        }
                    } catch {
                        await send(.recommendPlaylistsFailed("Failed to load recommended playlists. Please try again later."))
                    }
                }
            case .fetchRecommendPlaylistSongs(let playlistID):
                return .run { send in
                    do {
                        let playlistSongs = try await HomeFeature.fetchRecommendPlaylistSongs(with: playlistID)
                        await send(.playlistLoaded(playlistSongs))
                    } catch {
                        await send(.playlistFailed(error.localizedDescription))
                    }
                }
            case let .recommendPlaylistsLoaded(playlists):
                state.recommendedPlaylists = playlists
                state.errorMessage = nil
                if playlists.isEmpty {
                    state.errorMessage = "No recommended playlists available yet."
                } else if let firstPlaylist = playlists.first, let playlistID = firstPlaylist.id {
                    let playlistIDString = playlistID.uuidString
                    state.selectedPlaylistID = playlistIDString
                    return .send(.fetchRecommendPlaylistSongs(playlistIDString))
                }
                return .none
            case let .recommendPlaylistsFailed(error):
                state.errorMessage = error
                return .none
            case let .playlistLoaded(playlist):
                state.playlist = playlist
                state.errorMessage = nil
                return .none
            case let .startPlayback(playlistTracks):
                guard let firstTrack = playlistTracks.first else {
                    return .none
                }
                let trackTitle = firstTrack.title
                let trackStoreID = firstTrack.playbackStoreID
                return .run { send async in
                    do {
                        try await AudioManager.shared.playAppleMusicTrack(title: trackTitle, storeID: trackStoreID)
                    } catch {
                        await send(.playlistFailed("Playback failed: \(error.localizedDescription)"))
                    }
                }
            case let .playlistFailed(error):
                state.errorMessage = error
                return .none
            case .player:
                return .none
            }
        }
    }
}

struct ModelContextKey: DependencyKey {
    @MainActor
    static let liveValue: ModelContext = {
        do {
            let container = try ModelContainer(for: TokenEntity.self)
            return container.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

extension DependencyValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
}
