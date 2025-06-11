import ComposableArchitecture

@Reducer
struct TabBarReducer {
    struct State: Equatable {
        var playerState: PlayerReducer.State? = nil
        var generatorState = GeneratorFeature.State()
        var homeState = HomeReducer.State()
        var libraryState = LibraryReducer.State()
    }

    @CasePathable
    enum Action: Equatable {
        case player(PlayerReducer.Action)
        case generator(GeneratorFeature.Action)
        case home(HomeReducer.Action)
        case library(LibraryReducer.Action)
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
            default:
                return .none
            }
        }
    }
}
