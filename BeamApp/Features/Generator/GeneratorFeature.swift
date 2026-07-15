import Foundation
import ComposableArchitecture
import SwiftData

struct GeneratorFeature: Reducer {
    struct State: Equatable {
        var generatedMusicFileName: String? // Example: stores the generated file name
        var generationMetadata: (title: String, genre: String?, duration: Int?)? // Example
        var isRegistering: Bool = false
        var registrationError: String? = nil
    }

    enum Action: Equatable {
        case generateButtonTapped
        case generationCompleted(fileName: String, metadata: (String, String?, Int?)) // Generation completed and metadata delivered
        case registerGeneratedSong // Registration start action
        case registrationResponse(TaskResult<Song>) // Registration result action (uses TaskResult)
        // ...
    }

    @Dependency(\.someAIService) var aiService // AI generation service dependency (placeholder)
    @Dependency(\.modelContext) var modelContext // Used when fetching tokens, etc.

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .generateButtonTapped:
            // TODO: AI generation start logic
            return .run { send in
                 // Async AI generation call...
                 // let result = try await aiService.generate(...)
                 // await send(.generationCompleted(fileName: result.fileName, metadata: result.metadata))
            }

        case let .generationCompleted(fileName, metadata):
            state.generatedMusicFileName = fileName
            state.generationMetadata = metadata
            // Generation is complete, start registration
            return .send(.registerGeneratedSong)

        case .registerGeneratedSong:
            guard !state.isRegistering,
                  let fileName = state.generatedMusicFileName,
                  let metadata = state.generationMetadata else {
                return .none
            }
            state.isRegistering = true
            state.registrationError = nil

            return .run { send in
                 do {
                     let token = try await HomeFeature.fetchToken(context: modelContext) // Fetch token
                     let registeredSong = try await HomeFeature.registerNewAISong(
                         with: token,
                         title: metadata.title,
                         fileName: fileName,
                         genre: metadata.genre,
                         duration: metadata.duration
                     )
                     await send(.registrationResponse(.success(registeredSong)))
                 } catch {
                     await send(.registrationResponse(.failure(error)))
                 }
            }

        case let .registrationResponse(.success(song)):
            state.isRegistering = false
            print("Successfully registered new AI song: \(song.title)")
            // TODO: Handle successful registration (for example, playlist API call or UI update)
            return .none

        case let .registrationResponse(.failure(error)):
            state.isRegistering = false
            state.registrationError = error.localizedDescription
            print("Failed to register AI song: \(error)")
            // TODO: Show error to the user
            return .none

        // ...
        }
    }
}
