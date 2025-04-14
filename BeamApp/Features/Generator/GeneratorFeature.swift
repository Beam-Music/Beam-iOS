import Foundation
import ComposableArchitecture
import SwiftData

struct GeneratorFeature: Reducer {
    struct State: Equatable {
        var generatedMusicFileName: String? // 예시: 생성된 파일 이름 저장
        var generationMetadata: (title: String, genre: String?, duration: Int?)? // 예시
        var isRegistering: Bool = false
        var registrationError: String? = nil
    }

    enum Action: Equatable {
        case generateButtonTapped
        case generationCompleted(fileName: String, metadata: (String, String?, Int?)) // 생성 완료 및 정보 전달
        case registerGeneratedSong // 등록 시작 액션
        case registrationResponse(TaskResult<Song>) // 등록 결과 처리 액션 (TaskResult 사용)
        // ...
    }

    @Dependency(\.someAIService) var aiService // AI 생성 서비스 의존성 (가상)
    @Dependency(\.modelContext) var modelContext // 토큰 가져오기 등 필요시

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .generateButtonTapped:
            // TODO: AI 생성 시작 로직
            return .run { send in
                 // AI 생성 비동기 호출...
                 // let result = try await aiService.generate(...)
                 // await send(.generationCompleted(fileName: result.fileName, metadata: result.metadata))
            }

        case let .generationCompleted(fileName, metadata):
            state.generatedMusicFileName = fileName
            state.generationMetadata = metadata
            // 생성이 완료되었으므로 등록 시작
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
                     let token = try await HomeFeature.fetchToken(context: modelContext) // 토큰 가져오기
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
            // TODO: 등록 성공 후 처리 (예: 특정 플레이리스트에 추가 API 호출, UI 업데이트 등)
            return .none

        case let .registrationResponse(.failure(error)):
            state.isRegistering = false
            state.registrationError = error.localizedDescription
            print("Failed to register AI song: \(error)")
            // TODO: 사용자에게 에러 표시
            return .none

        // ...
        }
    }
}
