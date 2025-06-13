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
                // Convert MusicSearchResult to PlayableTrackDTO
                let track = PlayableTrackDTO(
                    id: UUID(),
                    title: musicResult.title,
                    artistName: musicResult.artist,
                    playbackUrl: nil,
                    playbackStoreID: musicResult.id,
                    isAIGenerated: false,
                    duration: nil,
                    fileUrl: nil,
                    artworkURL: musicResult.artworkURL
                )
                let playerState = PlayerReducer.State(playlist: [track], currentIndex: 0)
                return .send(.setPlayerState(playerState))
            default:
                return .none
            }
        }
    }
}
