import Vapor
import Fluent

struct AISongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiSongs = routes.grouped("api", "ai-songs")
        
        aiSongs.get(use: getAllAISongs)
        aiSongs.get(":aiSongID", use: getAISong)
        
        // Add authentication middleware for protected routes if needed
        let protected = aiSongs.grouped(JWTAuthenticator())
        protected.post(use: createAISong)
    }
    
    // Get all AI songs
    func getAllAISongs(req: Request) async throws -> [AISongDTO] {
        let aiSongs = try await AiSong.query(on: req.db).all()
        
        var aiSongDTOs: [AISongDTO] = []
        for aiSong in aiSongs {
            // If song has a parent song, get the artist from there
            if let songID = aiSong.$song.id {
                if let song = try await Song.find(songID, on: req.db),
                   let artistID = song.$artist.id,
                   let artist = try await Artist.find(artistID, on: req.db) {
                    let dto = AISongDTO(aiSong: aiSong, artistName: artist.name)
                    aiSongDTOs.append(dto)
                }
            } else {
                // Default artist name for AI-generated songs without a parent
                let dto = AISongDTO(aiSong: aiSong, artistName: "AI Generated")
                aiSongDTOs.append(dto)
            }
        }
        
        return aiSongDTOs
    }
    
    // Get a specific AI song
    func getAISong(req: Request) async throws -> AISongDTO {
        guard let aiSongID = req.parameters.get("aiSongID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let aiSong = try await AiSong.find(aiSongID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Determine artist name
        var artistName = "AI Generated"
        if let songID = aiSong.$song.id,
           let song = try await Song.find(songID, on: req.db),
           let artistID = song.$artist.id,
           let artist = try await Artist.find(artistID, on: req.db) {
            artistName = artist.name
        }
        
        return AISongDTO(aiSong: aiSong, artistName: artistName)
    }
    
    // Create a new AI song (protected route)
    func createAISong(req: Request) async throws -> AISongDTO {
        let input = try req.content.decode(CreateAISongInput.self)
        
        let aiSong = AiSong(
            title: input.title,
            genre: input.genre,
            releaseDate: input.releaseDate ?? Date(),
            duration: input.duration,
            isAIGenerated: true,
            filePath: input.filePath,
            songID: input.songID
        )
        
        try await aiSong.save(on: req.db)
        
        // Get artist name
        var artistName = "AI Generated"
        if let songID = input.songID,
           let song = try await Song.find(songID, on: req.db),
           let artistID = song.$artist.id,
           let artist = try await Artist.find(artistID, on: req.db) {
            artistName = artist.name
        }
        
        return AISongDTO(aiSong: aiSong, artistName: artistName)
    }
}

// Input struct for creating an AI song
struct CreateAISongInput: Content {
    let title: String
    let genre: String
    let releaseDate: Date?
    let duration: Int
    let filePath: String
    let songID: UUID?
}
