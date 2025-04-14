import Vapor

struct AISongDTO: Content {
    let id: UUID
    let title: String
    let artistName: String
    let genre: String
    let releaseDate: Date
    let duration: Int
    let fileURL: String
    let isAIGenerated: Bool
    
    init(aiSong: AiSong, artistName: String) {
        self.id = aiSong.id!
        self.title = aiSong.title
        self.artistName = artistName
        self.genre = aiSong.genre
        self.releaseDate = aiSong.releaseDate
        self.duration = aiSong.duration
        self.fileURL = aiSong.fileURL
        self.isAIGenerated = aiSong.isAIGenerated
    }
}
