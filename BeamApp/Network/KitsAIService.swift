import Foundation

struct KitsPaginatedResponse<T: Decodable>: Decodable {
    let data: [T]
}

struct KitsVoiceModel: Decodable {
    let id: Int
    let title: String
    let isUsable: Bool?
    let tags: [String]?
    let imageUrl: String?
    let demoUrl: String?
}

struct KitsInferenceJob: Decodable {
    let id: Int
    let createdAt: String?
    let type: String?
    let voiceModelId: String?
    let status: String
    let jobStartTime: String?
    let jobEndTime: String?
    let outputFileUrl: String?
    let lossyOutputFileUrl: String?
    let recombinedAudioFileUrl: String?
}

enum KitsAIError: LocalizedError {
    case missingAPIKey
    case invalidVoiceModelId
    case invalidURL
    case invalidResponse
    case serverError(String)
    case timedOut
    case jobFailed(String)
    case noOutputURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Kits AI API key is not configured. Set APIKeys.kitsAI."
        case .invalidVoiceModelId:
            return "Kits AI voiceModelId is invalid."
        case .invalidURL:
            return "Kits AI URL is invalid."
        case .invalidResponse:
            return "Kits AI response is invalid."
        case .serverError(let message):
            return "Kits AI server error: \(message)"
        case .timedOut:
            return "Kits AI conversion timed out."
        case .jobFailed(let message):
            return "Kits AI conversion failed: \(message)"
        case .noOutputURL:
            return "Could not find the Kits AI result file URL."
        }
    }
}

final class KitsAIClient {
    private let baseURL = "https://arpeggi.io/api/kits/v1"
    private let apiKey: String

    static let fallbackVoices: [VoiceInfo] = [
        VoiceInfo(
            id: "1014961",
            name: "Female LoFi",
            category: "Kits AI",
            description: "Kits quick start example model",
            previewUrl: nil,
            language: nil,
            voiceType: "singer"
        ),
        VoiceInfo(
            id: "110784",
            name: "Male Pop",
            category: "Kits AI",
            description: "Public singing voice model",
            previewUrl: nil,
            language: nil,
            voiceType: "singer"
        )
    ]

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    private func authorizedRequest(url: URL) throws -> URLRequest {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KitsAIError.missingAPIKey
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    func fetchVoiceModels(page: Int = 1, perPage: Int = 50) async throws -> [KitsVoiceModel] {
        guard var components = URLComponents(string: "\(baseURL)/voice-models") else {
            throw KitsAIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "order", value: "asc"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "perPage", value: String(perPage))
        ]
        guard let url = components.url else { throw KitsAIError.invalidURL }

        var request = try authorizedRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KitsAIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("❌ Kits fetchVoiceModels error [\(httpResponse.statusCode)]: \(body)")
            throw KitsAIError.serverError(body)
        }

        return try JSONDecoder().decode(KitsPaginatedResponse<KitsVoiceModel>.self, from: data).data
    }

    func createVoiceConversionJob(audioData: Data, voiceModelId: Int) async throws -> KitsInferenceJob {
        guard let url = URL(string: "\(baseURL)/voice-conversions") else {
            throw KitsAIError.invalidURL
        }

        var request = try authorizedRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1800

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voiceModelId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(voiceModelId)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"soundFile\"; filename=\"audio.mp3\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1800
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KitsAIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("❌ Kits createVoiceConversionJob error [\(httpResponse.statusCode)]: \(body)")
            throw KitsAIError.serverError(body)
        }

        let responseText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("✅ Kits createVoiceConversionJob response: \(responseText)")
        return try JSONDecoder().decode(KitsInferenceJob.self, from: data)
    }

    func fetchVoiceConversionJob(id: Int) async throws -> KitsInferenceJob {
        guard let url = URL(string: "\(baseURL)/voice-conversions/\(id)") else {
            throw KitsAIError.invalidURL
        }

        var request = try authorizedRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KitsAIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("❌ Kits fetchVoiceConversionJob error [\(httpResponse.statusCode)]: \(body)")
            throw KitsAIError.serverError(body)
        }

        return try JSONDecoder().decode(KitsInferenceJob.self, from: data)
    }

    func waitForJobCompletion(id: Int, timeout: TimeInterval = 1800) async throws -> KitsInferenceJob {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let job = try await fetchVoiceConversionJob(id: id)
            switch job.status.lowercased() {
            case "success":
                return job
            case "error", "failed":
                throw KitsAIError.jobFailed(job.status)
            case "cancelled":
                throw KitsAIError.jobFailed("cancelled")
            default:
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        throw KitsAIError.timedOut
    }

    func downloadAudio(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw KitsAIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw KitsAIError.invalidResponse
        }
        return data
    }

    func fetchVoiceInfos(limit: Int = 50) async throws -> [VoiceInfo] {
        let models = try await fetchVoiceModels(perPage: limit)
        let mapped = models
            .filter { $0.isUsable ?? true }
            .map {
                VoiceInfo(
                    id: String($0.id),
                    name: $0.title,
                    category: "Kits AI",
                    description: $0.tags?.joined(separator: ", "),
                    previewUrl: $0.demoUrl,
                    language: nil,
                    voiceType: "singer"
                )
            }

        return mapped.isEmpty ? Self.fallbackVoices : mapped
    }
}

final class KitsAIVoiceConversionProvider: VoiceConversionProvider {
    func convert(audioData: Data, voiceId: String, voiceType: String?, trimStart: Double?, trimDuration: Double?) async throws -> Data {
        guard let voiceModelId = Int(voiceId) else {
            throw KitsAIError.invalidVoiceModelId
        }

        let client = KitsAIClient(apiKey: APIKeys.kitsAI)
        let job = try await client.createVoiceConversionJob(audioData: audioData, voiceModelId: voiceModelId)
        let completedJob = try await client.waitForJobCompletion(id: job.id)

        if let url = completedJob.recombinedAudioFileUrl, !url.isEmpty {
            return try await client.downloadAudio(from: url)
        }
        if let url = completedJob.outputFileUrl, !url.isEmpty {
            return try await client.downloadAudio(from: url)
        }
        if let url = completedJob.lossyOutputFileUrl, !url.isEmpty {
            return try await client.downloadAudio(from: url)
        }
        throw KitsAIError.noOutputURL
    }
}
