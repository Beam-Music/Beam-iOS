//
//  JamendoModels.swift
//  BeamApp
//

import Foundation

struct JamendoResponse<T: Codable>: Codable {
    let headers: JamendoHeaders
    let results: [T]
}

struct JamendoHeaders: Codable {
    let status: String
    let code: Int
    let results_count: Int
}

struct JamendoTrack: Codable, Identifiable {
    let id: String
    let name: String
    let artist_name: String
    let album_name: String?
    let audio: String
    let audiodownload: String
    let image: String
    let album_image: String?
    let duration: Int

    func toPlayableTrackDTO() -> PlayableTrackDTO {
        PlayableTrackDTO(
            id: UUID(),
            title: name,
            artistName: artist_name,
            playbackUrl: audio,
            playbackStoreID: nil,
            isAIGenerated: false,
            duration: Double(duration),
            fileUrl: audio,
            artworkURL: URL(string: image)
        )
    }

    func toMusicSearchResult() -> MusicSearchResult {
        MusicSearchResult(
            id: id,
            title: name,
            artist: artist_name,
            artworkURL: URL(string: image),
            isExplicit: false,
            playbackURL: audio,
            genre: nil
        )
    }
}

struct JamendoArtist: Codable, Identifiable {
    let id: String
    let name: String
    let image: String
}
