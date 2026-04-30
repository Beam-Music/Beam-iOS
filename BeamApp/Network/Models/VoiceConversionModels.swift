import Foundation

// Voice conversion models
public struct VoiceInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String?
    public let previewUrl: String?
    public let language: [String]?
    public let voiceType: String? // "default", "singer", "custom"
    
    public init(id: String, name: String, category: String, description: String?, previewUrl: String?, language: [String]? = nil, voiceType: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.previewUrl = previewUrl
        self.language = language
        self.voiceType = voiceType
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "voiceId"
        case name
        case category
        case description
        case previewUrl = "preview_url"
        case language
        case voiceType
    }
}

// Voice list response model
public struct VoiceListResponse: Codable {
    public let voices: [VoiceInfo]
    public let categories: [String: [VoiceInfo]]
    public let totalCount: Int
    public let breakdown: VoiceBreakdown
    
    enum CodingKeys: String, CodingKey {
        case voices
        case categories
        case totalCount = "total_count"
        case breakdown
    }
}

public struct VoiceBreakdown: Codable {
    public let defaultCount: Int
    public let singersCount: Int
    public let customCount: Int
    
    enum CodingKeys: String, CodingKey {
        case defaultCount = "default"
        case singersCount = "singers"
        case customCount = "custom"
    }
}


public struct VoiceConversionRequest: Codable {
    public let sourceAudio: Data
    public let voiceId: String
    public let outputFormat: String
    
    public init(sourceAudio: Data, voiceId: String, outputFormat: String) {
        self.sourceAudio = sourceAudio
        self.voiceId = voiceId
        self.outputFormat = outputFormat
    }
    
    enum CodingKeys: String, CodingKey {
        case sourceAudio = "source_audio"
        case voiceId = "voice_id"
        case outputFormat = "output_format"
    }
}

public struct VoiceConversionResponse: Codable {
    public let success: Bool
    public let message: String?
    public let error: String?
    public let audioUrl: String?
    
    public init(success: Bool, message: String?, error: String?, audioUrl: String?) {
        self.success = success
        self.message = message
        self.error = error
        self.audioUrl = audioUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case error
        case audioUrl = "audio_url"
    }
} 