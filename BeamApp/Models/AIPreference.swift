import Foundation

struct AIPreference: Codable, Equatable {
    var id: UUID?
    var userId: UUID
    var enableAIMusic: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    init(id: UUID? = nil, userId: UUID, enableAIMusic: Bool, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.enableAIMusic = enableAIMusic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case enableAIMusic = "enable_ai_music"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
