//
//  Endpoints.swift
//  BeamApp
//
//  Created by freed on 9/19/24.
//
import Foundation

struct APIKeys {
    static let lalalAI = "66811d1fc63d48bc"
    static let kitsAI = "WTRMTTD1.OSRELYWRZHlJPgGMD8H8spVw"
}

struct Endpoints {
    private static func configuredURL(for key: String, fallback: String) -> String {
        if let envValue = ProcessInfo.processInfo.environment[key], !envValue.isEmpty {
            return envValue
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty {
            return plistValue
        }

        return fallback
    }

    private static let defaultLocalBaseURL: String = {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8080"
        #else
        return "http://192.168.0.75:8080"
        #endif
    }()

    private static let defaultLocalBeamSVCBaseURL: String = {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8081"
        #else
        return "http://192.168.0.75:8081"
        #endif
    }()

    static let baseURL = configuredURL(for: "BEAM_API_BASE_URL", fallback: defaultLocalBaseURL)
    static let beamSVCBaseURL = configuredURL(for: "BEAM_SVC_BASE_URL", fallback: defaultLocalBeamSVCBaseURL)

    struct Auth {
        static let login = "\(baseURL)/api/users/login"
        static let register = "\(baseURL)/api/users/register"
        static let verify = "\(baseURL)/api/users/verify"
        static let sendVerificationCode = "\(baseURL)/api/users/send-verification-code"
    }
    
    struct History {
        static let ListeningHistory = "\(baseURL)/listening-history"
    }
    
    struct AISong {
        static let register = "\(baseURL)/api/ai-songs/register"
        static let playable = "\(baseURL)/api/ai-songs/playable"
        static let nextTrack = "\(baseURL)/api/ai-songs/next-track"
    }

    struct Playlist {
        static let userPlaylist = "\(baseURL)/user-playlists"
        static func userPlaylistSongs(playlistID: String) -> String { "\(userPlaylist)/\(playlistID)/songs" }

        static let recommendPlaylists = "\(baseURL)/recommend-playlists"
        static func recommendPlaylistsSongs(playlistID: String) -> String { "\(recommendPlaylists)/\(playlistID)/songs" }
    }
    
    struct User {
        static let profile = "\(baseURL)/users/profile"
    }
    
    struct AIPreference {
        static func getPreference(userId: UUID) -> String {
            return "\(baseURL)/api/ai-preferences/\(userId)"
        }
        static func updatePreference(userId: UUID) -> String {
            return "\(baseURL)/api/ai-preferences/\(userId)"
        }
        static let createPreference = "\(baseURL)/api/ai-preferences"
    }

    static let aiConvert = "\(beamSVCBaseURL)/ai-convert"
    
    struct VoiceConversion {
        static let list = "\(baseURL)/ai-convert/voices"
        static let convert = "\(baseURL)/ai-convert/voice-conversion"
    }

    struct Jamendo {
        static let baseURL = "https://api.jamendo.com/v3.0"
        static let clientId = "YOUR_CLIENT_ID"
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
