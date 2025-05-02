//
//  RecommendPlaylist.swift
//  BeamApp
//
//  Created by freed on 10/14/24.
//

import Foundation

struct RecommendPlaylist: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    var user: User?
    
    struct User: Codable, Equatable {
        let id: UUID
        let username: String
    }
}
