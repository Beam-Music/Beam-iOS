import Vapor

struct AISongResponseDTO: Content {
    let id: UUID
    let title: String
    let artistName: String
    let duration: Double
    let fileURL: String
    let isAIGenerated: Bool = true
    
    init(aiSong: AiSong, artistName: String) {
        self.id = aiSong.id ?? UUID()
        self.title = aiSong.title
        self.artistName = artistName
        self.duration = aiSong.duration
        self.fileURL = aiSong.fileURL
    }
}
