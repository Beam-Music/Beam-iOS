import ComposableArchitecture
import Foundation

@Reducer
struct TabBarReducer {
    struct State: Equatable {
        var playerState: PlayerReducer.State?
        var generatorState: GeneratorFeature.State
        var homeState: HomeReducer.State
        var libraryState: LibraryReducer.State

        init(
            playerState: PlayerReducer.State? = nil,
            generatorState: GeneratorFeature.State = GeneratorFeature.State(),
            homeState: HomeReducer.State = HomeReducer.State(),
            libraryState: LibraryReducer.State = LibraryReducer.State()
        ) {
            self.playerState = playerState
            self.generatorState = generatorState
            self.homeState = homeState
            self.libraryState = libraryState
        }
    }

    @CasePathable
    enum Action: Equatable {
        case player(PlayerReducer.Action)
        case generator(GeneratorFeature.Action)
        case home(HomeReducer.Action)
        case library(LibraryReducer.Action)
        case setPlayerState(PlayerReducer.State?)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.generatorState, action: \.generator) {
            GeneratorFeature()
        }
        Scope(state: \.homeState, action: \.home) {
            HomeReducer()
        }
        Scope(state: \.libraryState, action: \.library) {
            LibraryReducer()
        }
        .ifLet(\.playerState, action: \.player) {
            PlayerReducer()
        }
        Reduce { state, action in
            switch action {
            case let .home(.playlistLoaded(playlist)),
                 let .library(.playlistLoaded(playlist)):
                if state.playerState?.playlist != playlist {
                    state.playerState?.playlist = playlist
                    state.playerState?.currentIndex = 0
                }
                return .none
            case let .library(.startPlayback(tracks)):
                return .send(.player(.startPlayback(tracks)))
            case let .setPlayerState(newPlayerState):
                print("[TabBarReducer] setPlayerState called, newPlayerState: \(String(describing: newPlayerState))")
                state.playerState = newPlayerState
                print("[TabBarReducer] state.playerState after set: \(String(describing: state.playerState))")
                if let playlist = newPlayerState?.playlist {
                    print("[TabBarReducer] Sending .player(.startPlayback) with playlist count: \(playlist.count)")
                    return .send(.player(.startPlayback(playlist)))
                }
                return .none
            case let .home(.playMusic(musicResult)):
                let seedTrack = PlayableTrackDTO(
                    id: UUID(),
                    title: musicResult.title,
                    artistName: musicResult.artist,
                    playbackUrl: musicResult.playbackURL,
                    playbackStoreID: musicResult.id,
                    isAIGenerated: false,
                    duration: nil,
                    fileUrl: nil,
                    artworkURL: musicResult.artworkURL
                )

                return .run { send in
                    do {
                        let relatedResults = try await AudiusService.shared.searchTracks(
                            query: musicResult.artist,
                            limit: 12
                        )
                        let filtered = relatedResults
                            .map { $0.toMusicSearchResult() }
                            .filter { $0.id != musicResult.id && $0.playbackURL != nil }

                        var playlist = [seedTrack]
                        playlist.append(contentsOf: filtered.prefix(9).map {
                            PlayableTrackDTO(
                                id: UUID(),
                                title: $0.title,
                                artistName: $0.artist,
                                playbackUrl: $0.playbackURL,
                                playbackStoreID: $0.id,
                                isAIGenerated: false,
                                duration: nil,
                                fileUrl: nil,
                                artworkURL: $0.artworkURL
                            )
                        })

                        if playlist.count == 1, let genre = musicResult.genre, !genre.isEmpty {
                            let fallbackResults = try await AudiusService.shared.searchTracks(query: genre, limit: 12)
                            playlist.append(contentsOf: fallbackResults
                                .map { $0.toMusicSearchResult() }
                                .filter { $0.id != musicResult.id && $0.playbackURL != nil }
                                .prefix(9)
                                .map {
                                    PlayableTrackDTO(
                                        id: UUID(),
                                        title: $0.title,
                                        artistName: $0.artist,
                                        playbackUrl: $0.playbackURL,
                                        playbackStoreID: $0.id,
                                        isAIGenerated: false,
                                        duration: nil,
                                        fileUrl: nil,
                                        artworkURL: $0.artworkURL
                                    )
                                }
                            )
                        }

                        let playerState = PlayerReducer.State(playlist: playlist, currentIndex: 0)
                        await send(.setPlayerState(playerState))
                    } catch {
                        let playerState = PlayerReducer.State(playlist: [seedTrack], currentIndex: 0)
                        await send(.setPlayerState(playerState))
                    }
                }
            default:
                return .none
            }
        }
    }
}
