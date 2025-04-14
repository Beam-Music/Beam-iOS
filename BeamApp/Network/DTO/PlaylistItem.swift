//
//  PlaylistItem.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//
import Foundation

struct PlaylistTrack: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let genre: String
    let releaseDate: String
    let duration: Int
}

struct UserPlaylist: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let userID: String
}

struct PlaylistSummaryDTO: Codable, Identifiable, Equatable {
    let id: UUID?
    let name: String
    let description: String?
}

struct PlayableTrackDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let artistName: String?
    let genre: String?
    let duration: Int?
    let artworkUrl: String?

    let isAIGenerated: Bool
    let playbackUrl: String?
    let musicKitID: String?
}
