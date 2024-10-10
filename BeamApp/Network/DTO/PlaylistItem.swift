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
