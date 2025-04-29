import Foundation

struct PlayableTrackDTO: Equatable, Identifiable, Codable {
    let id: UUID
    let title: String
    let artistName: String?
    let playbackUrl: String?
    let playbackStoreID: String? // MusicKit Store ID for Apple Music tracks
    let isAIGenerated: Bool
    let duration: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistName = "artist_name"
        case playbackUrl = "playback_url"
        case playbackStoreID = "playback_store_id"
        case isAIGenerated = "is_ai_generated"
        case duration
    }
} 