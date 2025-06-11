//
//  UserProfile.swift
//  BeamApp
//
//  Created by anonymous on 6/10/25.
//


import Foundation

struct UserProfile: Codable, Equatable {
    let id: String
    let username: String
    let profileImageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageUrl = "profileImageURL"
    }
}
