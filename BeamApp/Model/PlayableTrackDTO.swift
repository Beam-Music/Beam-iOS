import Foundation

struct PlayableTrackDTO: Equatable, Identifiable, Codable {
    let id: UUID
    let title: String
    let artistName: String?
    let playbackUrl: String?
    let playbackStoreID: String? // MusicKit Store ID for Apple Music tracks
    let isAIGenerated: Bool
    let duration: TimeInterval?
    let fileUrl: String? // URL for AI-generated music files
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistName = "artist_name"
        case playbackUrl = "playback_url"
        case playbackStoreID = "playback_store_id"
        case isAIGenerated = "is_ai_generated"
        case duration
        case fileUrl = "file_url"
    }
    
    init(id: UUID, title: String, artistName: String?, playbackUrl: String?, playbackStoreID: String?, isAIGenerated: Bool, duration: TimeInterval?, fileUrl: String?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.playbackUrl = playbackUrl
        self.playbackStoreID = playbackStoreID
        self.isAIGenerated = isAIGenerated
        self.duration = duration
        self.fileUrl = fileUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        playbackUrl = try container.decodeIfPresent(String.self, forKey: .playbackUrl)
        playbackStoreID = try container.decodeIfPresent(String.self, forKey: .playbackStoreID)
        isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
    }
} 