//
//  PlaylistItem.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

struct PlaylistTrack: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let genre: String
    let releaseDate: String
    let duration: Int
}

struct UserPlaylist: Codable, Equatable {
    let id: String
    let name: String
    let userID: String
}
