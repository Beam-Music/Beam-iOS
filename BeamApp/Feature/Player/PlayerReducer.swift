import ComposableArchitecture
import Dispatch
import Foundation
import SwiftData
import UIKit

//TODO: background에서 다음 노래로 넘어가지 않는 이슈 해결 필요함

@Reducer
struct PlayerReducer {
    struct State: Equatable {
        var playlist: [PlayableTrackDTO] = []
        var currentIndex: Int = 0
        var isPlaying: Bool = false
        var isTransitioning: Bool = false
        var isAIMusicEnabled: Bool = false
        var isLoadingAISongs: Bool = false
        var aiSongFetchError: String? = nil
        
        var currentTrack: PlayableTrackDTO? {
            guard !playlist.isEmpty, currentIndex >= 0, currentIndex < playlist.count else { return nil }
            return playlist[currentIndex]
        }
    }
    
    enum Action: Equatable {
        case syncPlaybackState
        case playPause
        case nextTrack
        case previousTrack
        case updateCurrentIndex(Int)
        case startPlayback([PlayableTrackDTO])
        case audioDidFinish 
        case playbackFinished
        case playbackError(String)
        case toggleAIMusic(Bool)
        case fetchAISongs
        case aiSongsResponse(TaskResult<[PlayableTrackDTO]>)
        case removeAISongsFromPlaylist
        case aiPreferenceResponse(Result<Bool, Error>)
        case loadAIPreference
        case internalPlaybackStateResponse(Bool)
        case nextTrackResponse(TaskResult<PlayableTrackDTO>)
        
        static func == (lhs: PlayerReducer.Action, rhs: PlayerReducer.Action) -> Bool {
            switch (lhs, rhs) {
            case (.syncPlaybackState, .syncPlaybackState): return true
            case (.playPause, .playPause): return true
            case (.nextTrack, .nextTrack): return true
            case (.previousTrack, .previousTrack): return true
            case let (.updateCurrentIndex(l), .updateCurrentIndex(r)): return l == r
            case (.startPlayback, .startPlayback): return true
            case (.audioDidFinish, .audioDidFinish): return true
            case (.playbackFinished, .playbackFinished): return true
            case let (.playbackError(l), .playbackError(r)): return l == r
            case let (.toggleAIMusic(l), .toggleAIMusic(r)): return l == r
            case (.fetchAISongs, .fetchAISongs): return true
            case let (.aiSongsResponse(l), .aiSongsResponse(r)):
                switch (l, r) {
                case let (.success(lhsTracks), .success(rhsTracks)): return lhsTracks == rhsTracks
                case (.failure, .failure): return true
                default: return false
                }
            case (.removeAISongsFromPlaylist, .removeAISongsFromPlaylist): return true
            case let (.aiPreferenceResponse(.success(l)), .aiPreferenceResponse(.success(r))): return l == r
            case (.aiPreferenceResponse(.failure), .aiPreferenceResponse(.failure)): return true
            case (.loadAIPreference, .loadAIPreference): return true
            case let (.internalPlaybackStateResponse(l), .internalPlaybackStateResponse(r)): return l == r
            case let (.nextTrackResponse(l), .nextTrackResponse(r)):
                switch (l, r) {
                case let (.success(lhs), .success(rhs)): return lhs == rhs
                case (.failure, .failure): return true
                default: return false
                }
            default: return false
            }
        }
    }
    
    @Dependency(\.aiPreferenceClient) private var aiPreferenceClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.audioManager) var audioManager
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.homeFeature) var homeFeature
    
    private func findNextTrackIndexSequentially(currentIndex: Int, playlistCount: Int) -> Int? {
        guard playlistCount > 0 else { return nil }
        return (currentIndex + 1) % playlistCount
    }
    
    private func findPreviousTrackIndexSequentially(currentIndex: Int, playlistCount: Int) -> Int? {
        guard playlistCount > 0 else { return nil }
        return (currentIndex - 1 + playlistCount) % playlistCount
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .syncPlaybackState:
                return .run { send in
                    let actualIsPlaying = await audioManager.isPlaying()
                    await send(.internalPlaybackStateResponse(actualIsPlaying))
                }
                
            case let .internalPlaybackStateResponse(actualIsPlaying):
                if state.isPlaying != actualIsPlaying {
                    state.isPlaying = actualIsPlaying
                }
                return .none
                
            case .playPause:
                let shouldPlay = !state.isPlaying
                state.isPlaying = shouldPlay
                return .run { [currentIndex = state.currentIndex, playlist = state.playlist] send in
                    if shouldPlay {
                        let didResume = await audioManager.tryResume()
                        if !didResume {
                            if currentIndex >= 0 && currentIndex < playlist.count {
                                await send(.startPlayback([playlist[currentIndex]]))
                            } else {
                                await send(.internalPlaybackStateResponse(false))
                            }
                        } else {
                            await send(.syncPlaybackState)
                        }
                    } else {
                        await audioManager.pause()
                        await send(.syncPlaybackState)
                    }
                }
                
            case .nextTrack:
                guard !state.playlist.isEmpty, !state.isTransitioning else {
                    return .none
                }
                if let nextIndex = findNextTrackIndexSequentially(
                    currentIndex: state.currentIndex,
                    playlistCount: state.playlist.count
                ) {
                    state.isTransitioning = true
                    state.currentIndex = nextIndex
                    let track = state.playlist[nextIndex]
                    return .run { send in
                        do {
                            if track.isAIGenerated {
                                if let fileUrl = track.fileUrl {
                                    try await audioManager.playAIMusic(
                                        from: fileUrl,
                                        title: track.title,
                                        artist: track.artistName ?? "AI Generated",
                                        artworkURL: track.artworkURL
                                    )
                                    await send(.internalPlaybackStateResponse(true))
                                    await send(.playbackFinished)
                                } else {
                                    await send(.playbackError("Missing file URL for AI track"))
                                }
                            } else {
                                if let audioURL = track.fileUrl ?? track.playbackUrl {
                                    try await audioManager.playAIMusic(
                                        from: audioURL,
                                        title: track.title,
                                        artist: track.artistName ?? "Unknown Artist",
                                        artworkURL: track.artworkURL
                                    )
                                    await send(.internalPlaybackStateResponse(true))
                                    await send(.playbackFinished)
                                } else {
                                    await send(.playbackError("No audio URL available"))
                                }
                            }
                        } catch {
                            await send(.playbackError(error.localizedDescription))
                        }
                    }
                }
                return .none
                
            case .previousTrack:
                guard !state.playlist.isEmpty, !state.isTransitioning else { return .none }
                if let prevIndex = findPreviousTrackIndexSequentially(
                    currentIndex: state.currentIndex,
                    playlistCount: state.playlist.count
                ) {
                    state.isTransitioning = true
                    state.currentIndex = prevIndex
                    let track = state.playlist[prevIndex]
                    return .run { send in
                        do {
                            if track.isAIGenerated {
                                if let fileUrl = track.fileUrl {
                                    try await audioManager.playAIMusic(
                                        from: fileUrl,
                                        title: track.title,
                                        artist: track.artistName ?? "AI Generated",
                                        artworkURL: track.artworkURL
                                    )
                                    await send(.internalPlaybackStateResponse(true))
                                    await send(.playbackFinished)
                                } else {
                                    await send(.playbackError("Missing file URL for AI track"))
                                }
                            } else {
                                if let audioURL = track.fileUrl ?? track.playbackUrl {
                                    try await audioManager.playAIMusic(
                                        from: audioURL,
                                        title: track.title,
                                        artist: track.artistName ?? "Unknown Artist",
                                        artworkURL: track.artworkURL
                                    )
                                    await send(.internalPlaybackStateResponse(true))
                                    await send(.playbackFinished)
                                } else {
                                    await send(.playbackError("No audio URL available"))
                                }
                            }
                        } catch {
                            await send(.playbackError(error.localizedDescription))
                        }
                    }
                }
                return .none
                
            case let .updateCurrentIndex(index):
                guard !state.playlist.isEmpty,
                      index >= 0, index < state.playlist.count,
                      !state.isTransitioning
                else { return .none }
                if state.currentIndex == index {
                    if state.isPlaying {
                        return .none
                    } else {
                        let track = state.playlist[index]
                        return .run { send in
                            do {
                                if track.isAIGenerated {
                                    if let fileUrl = track.fileUrl {
                                        try await audioManager.playAIMusic(
                                            from: fileUrl,
                                            title: track.title,
                                            artist: track.artistName ?? "AI Generated",
                                            artworkURL: track.artworkURL
                                        )
                                        await send(.internalPlaybackStateResponse(true))
                                        await send(.playbackFinished)
                                    } else {
                                        await send(.playbackError("Missing file URL for AI track"))
                                    }
                                } else {
                                    if let audioURL = track.fileUrl ?? track.playbackUrl {
                                        try await audioManager.playAIMusic(
                                            from: audioURL,
                                            title: track.title,
                                            artist: track.artistName ?? "Unknown Artist",
                                            artworkURL: track.artworkURL
                                        )
                                        await send(.internalPlaybackStateResponse(true))
                                        await send(.playbackFinished)
                                    } else {
                                        await send(.playbackError("No audio URL available"))
                                    }
                                }
                            } catch {
                                await send(.playbackError(error.localizedDescription))
                            }
                        }
                    }
                }
                state.isTransitioning = true
                state.currentIndex = index
                let track = state.playlist[index]
                return .run { send in
                    do {
                        if track.isAIGenerated {
                            if let fileUrl = track.fileUrl {
                                try await audioManager.playAIMusic(
                                    from: fileUrl,
                                    title: track.title,
                                    artist: track.artistName ?? "AI Generated",
                                    artworkURL: track.artworkURL
                                )
                                await send(.internalPlaybackStateResponse(true))
                                await send(.playbackFinished)
                            } else {
                                await send(.playbackError("Missing file URL for AI track"))
                            }
                        } else {
                            if let audioURL = track.fileUrl ?? track.playbackUrl {
                                try await audioManager.playAIMusic(
                                    from: audioURL,
                                    title: track.title,
                                    artist: track.artistName ?? "Unknown Artist",
                                    artworkURL: track.artworkURL
                                )
                                await send(.internalPlaybackStateResponse(true))
                                await send(.playbackFinished)
                            } else {
                                await send(.playbackError("No audio URL available"))
                            }
                        }
                    } catch {
                        await send(.playbackError(error.localizedDescription))
                    }
                }
                
            case let .startPlayback(tracks):
                state.playlist = tracks
                state.currentIndex = 0
                guard let track = state.currentTrack else {
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { send in
                        await audioManager.stop()
                    }
                }
                
                let backgroundTaskID = UIApplication.shared.beginBackgroundTask { }
                
                return .run { send in
                    do {
                        if track.isAIGenerated {
                            if let fileUrl = track.fileUrl {
                                try await audioManager.playAIMusic(
                                    from: fileUrl,
                                    title: track.title,
                                    artist: track.artistName ?? "AI Generated",
                                    artworkURL: track.artworkURL
                                )
                                await send(.internalPlaybackStateResponse(true))
                                await send(.playbackFinished)
                            } else {
                                await send(.playbackError("Missing file URL for AI track"))
                            }
                        } else {
                            if let audioURL = track.fileUrl ?? track.playbackUrl {
                                try await audioManager.playAIMusic(
                                    from: audioURL,
                                    title: track.title,
                                    artist: track.artistName ?? "Unknown Artist",
                                    artworkURL: track.artworkURL
                                )
                                await send(.internalPlaybackStateResponse(true))
                                await send(.playbackFinished)
                            } else {
                                await send(.playbackError("No audio URL available"))
                            }
                        }
                    } catch {
                        await send(.playbackError(error.localizedDescription))
                    }
                    
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
                
            case .playbackFinished:
                state.isTransitioning = false
                return .none
                
            case let .playbackError(errorString):
                state.isTransitioning = false
                state.isPlaying = false
                return .run { _ async in await audioManager.stop() }
                
            case let .toggleAIMusic(enabled):
                state.isAIMusicEnabled = enabled
                
                if enabled {
                    return .run { [modelContext] send in
                        do {
                            let token = try await HomeFeature.fetchToken(context: modelContext)
                            let response = try await HomeFeature.fetchPlayableAISongs(token: token)
                            await send(.aiSongsResponse(.success(response)))
                        } catch {
                            await send(.aiSongsResponse(.failure(error)))
                        }
                    }
                } else {
                    return .send(.removeAISongsFromPlaylist)
                }
                
            case .fetchAISongs:
                guard state.isAIMusicEnabled, !state.isLoadingAISongs else { return .none }
                state.isLoadingAISongs = true
                state.aiSongFetchError = nil
                
                return .run { [modelContext] send in
                    do {
                        let token = try await HomeFeature.fetchToken(context: modelContext)
                        let aiTracks = try await HomeFeature.fetchPlayableAISongs(token: token)
                        await send(.aiSongsResponse(.success(aiTracks)))
                    } catch {
                        await send(.aiSongsResponse(.failure(error)))
                    }
                }
                
            case let .aiSongsResponse(.success(aiTracks)):
                state.isLoadingAISongs = false
                state.aiSongFetchError = nil
                
                if aiTracks.isEmpty {
                    state.aiSongFetchError = "No AI tracks available yet. Please try again later."
                    return .none
                }
                
                let updatedAISongs = aiTracks.enumerated().map { index, track -> PlayableTrackDTO in
                    let newId = UUID()
                    let fileUrl = track.playbackUrl ?? "https://audio.jukehost.co.uk/gcP4CuiFEBSG8rTyRl0vwSWqRVP1XgTc"
                    return PlayableTrackDTO(
                        id: newId,
                        title: track.title,
                        artistName: track.artistName ?? "AI Generated",
                        playbackUrl: fileUrl,
                        playbackStoreID: nil,
                        isAIGenerated: true,
                        duration: track.duration ?? 180.0,
                        fileUrl: fileUrl,
                        artworkURL: nil
                    )
                }
                
                let wasPlaying = state.isPlaying
                let currentTrackId = state.currentTrack?.id
                
                state.playlist.removeAll { $0.isAIGenerated }
                state.playlist.append(contentsOf: updatedAISongs)
                
                if wasPlaying, let currentTrack = state.currentTrack, currentTrack.isAIGenerated {
                    state.currentIndex = state.playlist.count - updatedAISongs.count // Index of first AI song
                    state.isTransitioning = false // Reset transitioning state
                    return .send(.startPlayback([state.playlist[state.currentIndex]]))
                }
                
                if state.currentTrack == nil {
                    state.currentIndex = state.playlist.count - updatedAISongs.count
                    state.isTransitioning = false // Reset transitioning state
                    return .send(.startPlayback([state.playlist[state.currentIndex]]))
                }
                
                if let currentId = currentTrackId,
                   let newIndex = state.playlist.firstIndex(where: { $0.id == currentId }) {
                    state.currentIndex = newIndex
                    state.isTransitioning = false
                }
                
                return .none
                
            case let .aiSongsResponse(.failure(error)):
                state.isLoadingAISongs = false
                if (error as NSError).code == 404 {
                    state.aiSongFetchError = "No AI tracks available yet. Please try again later."
                } else {
                    state.aiSongFetchError = error.localizedDescription
                }
                return .none
                
            case .removeAISongsFromPlaylist:
                let originalPlaylist = state.playlist
                let originalIndex = state.currentIndex
                guard let trackBeingPlayed = state.currentTrack else {
                    state.playlist = []
                    state.currentIndex = 0
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { _ async in await audioManager.stop() }
                }
                
                let wasPlayingAITrack = trackBeingPlayed.isAIGenerated
                let wasPlaying = state.isPlaying
                let newPlaylist = originalPlaylist.filter { !$0.isAIGenerated }
                
                if newPlaylist.isEmpty {
                    state.playlist = []
                    state.currentIndex = 0
                    state.isPlaying = false
                    state.isTransitioning = false
                    return .run { _ async in await audioManager.stop() }
                }
                
                var nextIndex = 0
                var shouldStartPlayback = false
                
                if wasPlayingAITrack {
                    state.isTransitioning = false
                    var nextOriginalNonAIIndex = -1
                    var searchIndex = (originalIndex + 1) % originalPlaylist.count
                    
                    for _ in 0..<originalPlaylist.count {
                        if !originalPlaylist[searchIndex].isAIGenerated {
                            nextOriginalNonAIIndex = searchIndex
                            break
                        }
                        searchIndex = (searchIndex + 1) % originalPlaylist.count
                    }
                    
                    if nextOriginalNonAIIndex != -1,
                       let foundTrack = originalPlaylist[safe: nextOriginalNonAIIndex],
                       let indexInNewList = newPlaylist.firstIndex(where: { $0.id == foundTrack.id }) {
                        nextIndex = indexInNewList
                        shouldStartPlayback = wasPlaying
                    } else {
                        nextIndex = 0
                        shouldStartPlayback = wasPlaying
                    }
                } else {
                    if let indexInNewList = newPlaylist.firstIndex(where: { $0.id == trackBeingPlayed.id }) {
                        nextIndex = indexInNewList
                        shouldStartPlayback = false
                    } else {
                        nextIndex = 0
                        shouldStartPlayback = wasPlaying
                        state.isTransitioning = false
                    }
                }
                
                state.playlist = newPlaylist
                state.currentIndex = nextIndex
                
                if shouldStartPlayback {
                    state.isPlaying = true
                    return .send(.startPlayback([state.playlist[state.currentIndex]]))
                } else {
                    if !wasPlaying {
                        state.isPlaying = false
                    } else if !wasPlayingAITrack {
                        state.isPlaying = true
                    }
                    return .none
                }
                
            case .aiPreferenceResponse:
                return .none
                
            case .loadAIPreference:
                return .none
            case .audioDidFinish:
                state.isTransitioning = false
                return .none

            case .nextTrackResponse(_):
                return .none

            }
        }
    }
}

protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAIMusic(from urlString: String, title: String, artist: String, artworkURL: URL?) async throws
    func isPlaying() async -> Bool
    func tryResume() async -> Bool
    func seek(to seconds: Double) async
    var isAIPlaying: Bool { get }
}
private struct AudioManagerKey: DependencyKey {
    @MainActor
    static let liveValue: AudioManagerProtocol = AudioManager.shared
}

private struct HomeFeatureKey: DependencyKey {
    @MainActor
    static let liveValue: HomeFeature = HomeFeature()
}

extension DependencyValues {
    var audioManager: AudioManagerProtocol {
        get { self[AudioManagerKey.self] }
        set { self[AudioManagerKey.self] = newValue }
    }
    
    var homeFeature: HomeFeature {
        get { self[HomeFeatureKey.self] }
        set { self[HomeFeatureKey.self] = newValue }
    }
}
