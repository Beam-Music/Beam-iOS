import ComposableArchitecture

@Reducer
struct TabBarReducer {
    struct State: Equatable {
        var playerState = PlayerReducer.State()
        var generatorState = GeneratorFeature.State()
        var homeState = HomeReducer.State()
        var libraryState = LibraryReducer.State()
    }

    enum Action: Equatable {
        case player(PlayerReducer.Action)
        case generator(GeneratorFeature.Action)
        case home(HomeReducer.Action)
        case library(LibraryReducer.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.playerState, action: \.player) {
            PlayerReducer()
        }
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

                if state.playerState.playlist != playlist {
                    state.playerState.playlist = playlist
                    state.playerState.currentIndex = 0
                    // 다른 탭의 상태도 필요시 업데이트 (예: home/library 간 동기화)
                    // state.homeState.playlist = playlist // 필요 여부 확인
                    // state.libraryState.playlist = playlist // 필요 여부 확인
                    // 필요하다면 여기서 바로 .player(.startPlayback) 액션 전송 가능
                    // return .send(.player(.startPlayback))
                }
                return .none
            default:
                return .none
            }
        }
    }
}
