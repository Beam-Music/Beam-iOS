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
        var playlist: [PlayableTrackDTO] = []
        var errorMessage: String? = nil
        var playerState: PlayerReducer.State? = nil
        var selectedPlaylistID: String? = nil
        var recommendedPlaylists: [PlaylistSummaryDTO] = []
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case logOutButtonTapped
        case setNavigation(Route?)
        case fetchPlaylist(String)
        case selectPlaylist(PlaylistSummaryDTO)
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
            case .binding:
                return .none
                
            case let .selectPlaylist(playlist):
                guard let playlistID = playlist.id else {
                    print("HomeReducer: Selected playlist has no ID.")
                    return .none
                }
                let playlistIDString = playlistID.uuidString
                state.selectedPlaylistID = playlistIDString // String으로 할당
                return .send(.fetchRecommendPlaylistSongs(playlistIDString))
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
                
            case let .userPlaylistsLoaded(userPlaylists): // userPlaylists는 [PlaylistSummaryDTO]
                // --- 수정: firstPlaylist 및 그 ID(UUID?)를 안전하게 unwrap하고 String으로 변환 ---
                if let firstPlaylist = userPlaylists.first, let playlistID = firstPlaylist.id {
                    // UUID를 String으로 변환
                    let playlistIDString = playlistID.uuidString
                    // String? 타입인 state.selectedPlaylistID에 변환된 String 할당
                    state.selectedPlaylistID = playlistIDString
                    
                    // .fetchPlaylist 액션에도 변환된 String 전달
                    // (fetchPlaylist 액션이 String을 받는다고 가정)
                    return .send(.fetchPlaylist(playlistIDString))
                }
                // --- 수정 완료 ---
                // 첫 번째 플레이리스트가 없거나 ID가 nil이면 아무 작업 안 함
                return .none
                
            case let .selectPlaylist(playlist): // playlist는 PlaylistSummaryDTO
                // --- 수정: playlist.id (UUID?) unwrap 후 uuidString 사용 ---
                guard let playlistID = playlist.id else {
                    print("HomeReducer: Selected playlist has no ID in .selectPlaylist case.")
                    // ID가 없으면 상태 변경 및 액션 전송 안 함
                    return .none
                }
                // UUID를 String으로 변환
                let playlistIDString = playlistID.uuidString
                
                // 변환된 String을 state.selectedPlaylistID (String?)에 할당
                state.selectedPlaylistID = playlistIDString
                
                // .fetchRecommendPlaylistSongs 액션에도 변환된 String 전달
                return .send(.fetchRecommendPlaylistSongs(playlistIDString))
                // --- 수정 완료 ---
                
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
                
            case .fetchRecommendPlaylists:
                return .run { send in
                    do {
                        let recommendPlaylists = try await HomeFeature.fetchRecommendPlaylists()
                        await send(.recommendPlaylistsLoaded(recommendPlaylists))
                    } catch {
                        await send(.recommendPlaylistsFailed(error.localizedDescription))
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
                
            case let .recommendPlaylistsLoaded(playlists): // playlists는 [PlaylistSummaryDTO]
                state.recommendedPlaylists = playlists
                // --- 수정: firstPlaylist 및 그 ID(UUID?)를 안전하게 unwrap하고 String으로 변환 ---
                // if let으로 첫 번째 플레이리스트와 그 ID가 모두 nil이 아닌지 한 번에 확인
                if let firstPlaylist = playlists.first, let playlistID = firstPlaylist.id {
                    // UUID를 String으로 변환
                    let playlistIDString = playlistID.uuidString
                    // String? 타입인 state.selectedPlaylistID에 변환된 String 할당
                    state.selectedPlaylistID = playlistIDString
                    // .fetchRecommendPlaylistSongs 액션에도 변환된 String 전달
                    return .send(.fetchRecommendPlaylistSongs(playlistIDString))
                }
                return .none
                
                
            case let .recommendPlaylistsFailed(error):
                state.errorMessage = error
                return .none
                
            case let .playlistLoaded(playlist):
                state.playlist = playlist
                state.errorMessage = nil
//                return .send(.startPlayback(playlist))
                return .none
                
            case let .startPlayback(playlistTracks):
                guard let firstTrack = playlistTracks.first else {
                    print("Playback Error: No tracks provided to start playback.")
                    return .none
                }
                
                return .run { [title = firstTrack.title] send async in
                    do {
                        try await AudioManager.shared.playAppleMusicTrack(with: title)
                        
                    } catch {
                        print("Failed to initiate playback for track '\(title)': \(error)")
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
