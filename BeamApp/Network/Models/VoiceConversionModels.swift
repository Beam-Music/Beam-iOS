import Foundation

// Voice conversion models
public struct VoiceInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String?
    public let previewUrl: String?
    
    public init(id: String, name: String, category: String, description: String?, previewUrl: String?) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.previewUrl = previewUrl
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "voice_id"
        case name
        case category
        case description
        case previewUrl = "preview_url"
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