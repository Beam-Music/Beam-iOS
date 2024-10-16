//
//  Endpoints.swift
//  BeamApp
//
//  Created by freed on 9/19/24.
//
import Foundation

struct Endpoints {
    static let baseURL = 
//    "http://127.0.0.1:8080"
    "http://192.168.0.33:8080"


    struct Auth {
        static let login = "\(baseURL)/users/login"
        static let register = "\(baseURL)/users/register"
        static let verify = "\(baseURL)/users/verify"
    }
    
    struct History {
        static let ListeningHistory = "\(baseURL)/listening-history"
    }
    
    struct Playlist {
        static let userPlaylist = "\(baseURL)/user-playlists"
        static func userPlaylistSongs(playlistID: String) -> String {
            return "\(baseURL)/user-playlists/\(playlistID)/songs"
        }
        static let recommendPlaylists = "\(baseURL)/recommend-playlists"
        static func recommendPlaylistsSongs(playlistID: String) -> String {
            return "\(baseURL)/recommend-playlists/\(playlistID)/songs"
        }
    }
    
    struct User {
        static let profile = "\(baseURL)/users/profile"
    }
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: [String: Any]?

    init(path: String, method: HTTPMethod, queryItems: [URLQueryItem]? = nil, body: [String: Any]? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }
}

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}
