import Foundation
import ComposableArchitecture
import SwiftData // ModelContext 사용 위해 필요

// --- 의존성 정의 OK (별도 파일 또는 App 진입점에 있어야 함) ---
// import Dependencies
// struct ModelContextKey: DependencyKey { ... }
// extension DependencyValues { var modelContext: ModelContext { ... } }
// struct SomeAIService { ... } // 가상의 AI 서비스 클라이언트
// extension DependencyValues { var someAIService: SomeAIService { ... } }


struct Song: Codable, Identifiable, Equatable {
    let id: UUID?
    let title: String
    let artistName: String?
    let genre: String?
    let duration: Int?
    let isAIGenerated: Bool?
}


@Reducer
struct GeneratorFeature {
    struct State: Equatable {
        var generatedMusicFileName: String?
        struct GenerationMetadata: Equatable {
            let title: String
            let genre: String?
            let duration: Int?
        }
        var generationMetadata: GenerationMetadata?
        var isRegistering: Bool = false
        var registrationError: String? = nil
    }
    
    enum Action: Equatable {
        case generateButtonTapped
        case generationCompleted(fileName: String, metadata: State.GenerationMetadata)
        case registerGeneratedSong
        case registrationResponse(TaskResult<Song>)
    }
    
    @Dependency(\.someAIService) var aiService
    @Dependency(\.modelContext) var modelContext
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .generateButtonTapped:
                state.generatedMusicFileName = nil
                state.generationMetadata = nil
                state.isRegistering = false
                state.registrationError = nil
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    let dummyMetadata = State.GenerationMetadata(title: "Generated AI Song \(Int.random(in: 1...100))", genre: "Electronic", duration: 150)
                    await send(.generationCompleted(fileName: "generated_song_\(UUID().uuidString).mp3", metadata: dummyMetadata))
                }
                
            case let .generationCompleted(fileName, metadata):
                state.generatedMusicFileName = fileName
                state.generationMetadata = metadata
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
            
                    await send(
                        .registrationResponse(
                            await TaskResult {
                                let token = try await HomeFeature.fetchToken(context: modelContext)
                                return try await HomeFeature.registerNewAISong(
                                    with: token,
                                    title: metadata.title,
                                    fileName: fileName,
                                    genre: metadata.genre,
                                    duration: metadata.duration
                                )
                            }
                        )
                    )
                }
            case let .registrationResponse(.success(song)):
                state.isRegistering = false
                return .none
                
            case let .registrationResponse(.failure(error)):
                state.isRegistering = false
                state.registrationError = error.localizedDescription
                return .none
            }
        }
    }
}

struct SomeAIService {
    var generate: @Sendable () async throws -> (fileName: String, metadata: GeneratorFeature.State.GenerationMetadata)
}

extension SomeAIService: DependencyKey {
    static let liveValue = Self(generate: { /* 실제 생성 로직 */ throw NSError(domain: "", code: 0) })
    static let testValue = Self(generate: { ("test.mp3", .init(title: "Test", genre: "Test", duration: 10)) })
}

extension DependencyValues {
    var someAIService: SomeAIService {
        get { self[SomeAIService.self] }
        set { self[SomeAIService.self] = newValue }
    }
}
