//
//  LIsteningHistoryItem.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//

import Foundation

struct ListeningHistoryItem: Codable, Identifiable, Equatable {
    let id: String
    let listenedAt: String
    let playDuration: Int
    let title: String
    let artist: String
    let genre: String
    let song: Song
    let user: User

    struct Song: Codable, Identifiable, Equatable {
        let id: String
    }
    
    struct AiSong: Identifiable, Equatable {
        let id: String
        let title: String
        let artist: String
        let genre: String
        let generatedAt: Date
        let serverPath: String
        
        // TODO: check this url
        var fileURL: URL {
            URL(string: "\(Endpoints.baseURL)/ai-songs/\(serverPath)")!
        }
    }


    struct User: Codable, Equatable {
        let id: String
    }
}


