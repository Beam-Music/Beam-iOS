import Vapor
import Fluent

final class AIPreference: Model, Content {
    static let schema = "ai_preferences"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "user_id")
    var userId: UUID
    
    @Field(key: "enable_ai_music")
    var enableAIMusic: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, enableAIMusic: Bool) {
        self.id = id
        self.userId = userId
        self.enableAIMusic = enableAIMusic
    }
}
