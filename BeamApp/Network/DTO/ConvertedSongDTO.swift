import Foundation

struct CreateConvertedSongRequestDTO: Codable {
    let sourceTrackId: String?
    let sourcePlaybackUrl: String?
    let title: String
    let artistName: String?
    let artworkUrl: String?
    let voiceId: String
    let voiceName: String
    let voiceType: String?
}

struct ConvertedSongCreateResponseDTO: Codable, Equatable {
    let id: UUID
    let status: String
    let jobId: String?
    let isDuplicate: Bool
}

struct ConvertedSongDTO: Codable, Equatable, Identifiable {
    let id: UUID
    let sourceTrackId: String?
    let sourcePlaybackUrl: String?
    let title: String
    let artistName: String?
    let artworkUrl: String?
    let voiceId: String
    let voiceName: String
    let voiceType: String?
    let status: String
    let jobId: String?
    let resultFileUrl: String?
    let errorMessage: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ConvertedSongStatusDTO: Codable, Equatable {
    let id: UUID
    let status: String
    let progress: Int?
    let stage: String?
    let resultFileUrl: String?
    let errorMessage: String?
}
