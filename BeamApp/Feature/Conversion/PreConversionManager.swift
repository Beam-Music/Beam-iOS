import Foundation
import SwiftUI

enum PreConversionJobStatus: String, Codable, Equatable {
    case queued
    case converting
    case completed
    case failed

    var label: String {
        switch self {
        case .queued: return "대기중"
        case .converting: return "변환중"
        case .completed: return "완료"
        case .failed: return "실패"
        }
    }
}

struct PreConversionJobRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let trackKey: String
    let title: String
    let artistName: String?
    let playbackUrl: String?
    let artworkURL: String?
    let voiceId: String
    let voiceName: String
    let voiceType: String?
    var convertedSongID: UUID?
    var jobId: String?
    var status: PreConversionJobStatus
    var localFilePath: String?
    var errorMessage: String?
    let createdAt: Date
    var updatedAt: Date
}

struct ConvertedSongPlayableItemDTO: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let artistName: String?
    let playbackUrl: String?
    let fileUrl: String?
    let artworkUrl: String?
    let isAIGenerated: Bool
}

@MainActor
final class PreConversionManager: ObservableObject {
    static let shared = PreConversionManager()

    @Published private(set) var jobs: [PreConversionJobRecord] = []
    @Published private(set) var convertedSongs: [ConvertedSongDTO] = []
    @Published private(set) var availableVoices: [VoiceInfo] = []
    @Published private(set) var preferredVoiceId: String?
    @Published var lastErrorMessage: String?

    private let jobsKey = "pre_conversion.jobs"
    private let preferredVoiceKey = "pre_conversion.preferred_voice_id"

    private init() {
        loadPersistedState()
        loadPreferredVoiceId()
        Task {
            await loadAvailableVoices()
            await syncConvertedSongsFromServer()
            await resumePendingJobsIfNeeded()
        }
    }

    func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: jobsKey),
           let decoded = try? JSONDecoder().decode([PreConversionJobRecord].self, from: data) {
            jobs = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func loadPreferredVoiceId() {
        preferredVoiceId = UserDefaults.standard.string(forKey: preferredVoiceKey)
    }

    func setPreferredVoice(_ voice: VoiceInfo) {
        preferredVoiceId = voice.id
        UserDefaults.standard.set(voice.id, forKey: preferredVoiceKey)
    }

    func preferredVoice() -> VoiceInfo? {
        if let preferredVoiceId {
            return availableVoices.first(where: { $0.id == preferredVoiceId }) ?? availableVoices.first
        }
        return availableVoices.first(where: { $0.voiceType == "singer" }) ?? availableVoices.first
    }

    func refreshConvertedRecords() {
        Task {
            await syncConvertedSongsFromServer()
        }
    }

    func loadAvailableVoices() async {
        if !availableVoices.isEmpty { return }
        do {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw VoiceConversionError.serverError("Invalid voice list URL")
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VoiceConversionError.serverError("음성 목록을 불러오지 못했습니다.")
            }
            struct VoiceListPayload: Decodable { let voices: [VoiceInfo] }
            availableVoices = try JSONDecoder().decode(VoiceListPayload.self, from: data).voices
        } catch {
            availableVoices = [
                VoiceInfo(
                    id: "dionn_v1_singing",
                    name: "Dionn V1 Singing",
                    category: "Custom Licensed",
                    description: "Beam SVC fallback voice",
                    previewUrl: nil,
                    language: ["en"],
                    voiceType: "singer"
                )
            ]
        }
    }

    func statusText(for track: PlayableTrackDTO) -> String? {
        if let record = latestJob(for: track) {
            return record.status.label
        }
        if latestConvertedTrack(for: track) != nil {
            return PreConversionJobStatus.completed.label
        }
        return nil
    }

    func statusBadgeText(for track: PlayableTrackDTO, includeWarmupHint: Bool = false) -> String? {
        if let record = latestJob(for: track) {
            return "\(record.voiceName) · \(record.status.label)"
        }
        if latestConvertedTrack(for: track) != nil {
            return PreConversionJobStatus.completed.label
        }
        if includeWarmupHint, let voice = preferredVoice() {
            return "자동 준비 중 · \(voice.name)"
        }
        return nil
    }

    func warmup(track: PlayableTrackDTO) async {
        guard TokenStorage.shared.fetchToken() != nil else { return }
        guard let voice = preferredVoice() else { return }
        await enqueue(track: track, voice: voice)
    }

    func latestJob(for track: PlayableTrackDTO) -> PreConversionJobRecord? {
        let key = trackKey(for: track)
        return jobs
            .filter { $0.trackKey == key }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func latestConvertedTrack(for track: PlayableTrackDTO, voiceId: String? = nil) -> PlayableTrackDTO? {
        let key = trackKey(for: track)
        guard let dto = convertedSongs.first(where: {
            $0.status == "completed" && match(convertedSong: $0, track: track, trackKey: key, voiceId: voiceId)
        }) else {
            return nil
        }
        return playableTrack(from: dto)
    }

    func convertedTracks(for sourceTracks: [PlayableTrackDTO]) -> [PlayableTrackDTO] {
        sourceTracks.compactMap { latestConvertedTrack(for: $0) }
    }

    var currentConvertedTracks: [PlayableTrackDTO] {
        let grouped = Dictionary(grouping: convertedSongs.filter { $0.status == "completed" }) { song in
            self.convertedSongKey(song)
        }

        return grouped.values.compactMap { songs in
            let preferred = songs.sorted {
                let leftScore = self.preferenceScore(for: $0)
                let rightScore = self.preferenceScore(for: $1)
                if leftScore != rightScore { return leftScore > rightScore }
                return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
            }.first
            return preferred.flatMap(playableTrack(from:))
        }
    }

    func enqueue(track: PlayableTrackDTO, voice: VoiceInfo) async {
        do {
            guard let token = TokenStorage.shared.fetchToken() else {
                throw VoiceConversionError.serverError("로그인이 필요합니다.")
            }

            setPreferredVoice(voice)

            let key = trackKey(for: track)
            if latestConvertedTrack(for: track, voiceId: voice.id) != nil {
                return
            }
            if let duplicate = jobs.first(where: { $0.trackKey == key && $0.voiceId == voice.id && $0.status != .failed }) {
                if duplicate.status == .queued || duplicate.status == .converting {
                    await pollUntilFinished(recordID: duplicate.id)
                }
                return
            }

            let sourcePlaybackUrl = try await resolveSourcePlaybackURL(for: track)
            let requestBody = CreateConvertedSongRequestDTO(
                sourceTrackId: track.playbackStoreID,
                sourcePlaybackUrl: sourcePlaybackUrl,
                title: track.title,
                artistName: track.artistName,
                artworkUrl: track.artworkURL?.absoluteString,
                voiceId: voice.id,
                voiceName: voice.name,
                voiceType: voice.voiceType
            )

            var request = URLRequest(url: URL(string: Endpoints.ConvertedSong.base)!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VoiceConversionError.serverError(String(data: data, encoding: .utf8) ?? "변환 요청 실패")
            }

            let payload = try decode(ConvertedSongCreateResponseDTO.self, from: data)
            let record = PreConversionJobRecord(
                id: UUID(),
                trackKey: key,
                title: track.title,
                artistName: track.artistName,
                playbackUrl: sourcePlaybackUrl,
                artworkURL: track.artworkURL?.absoluteString,
                voiceId: voice.id,
                voiceName: voice.name,
                voiceType: voice.voiceType,
                convertedSongID: payload.id,
                jobId: payload.jobId,
                status: mapStatus(payload.status),
                localFilePath: nil,
                errorMessage: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            upsert(record)
            await pollUntilFinished(recordID: record.id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func syncConvertedSongsFromServer() async {
        do {
            guard let token = TokenStorage.shared.fetchToken() else { return }
            var request = URLRequest(url: URL(string: Endpoints.ConvertedSong.base)!)
            request.httpMethod = "GET"
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }

            let songs = try decode([ConvertedSongDTO].self, from: data)
                .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            convertedSongs = songs
            syncJobsFromConvertedSongs(songs)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func resumePendingJobsIfNeeded() async {
        for record in jobs where record.status == .queued || record.status == .converting {
            await pollUntilFinished(recordID: record.id)
        }
    }

    private func pollUntilFinished(recordID: UUID) async {
        guard let token = TokenStorage.shared.fetchToken() else { return }
        while let record = jobs.first(where: { $0.id == recordID }),
              let convertedSongID = record.convertedSongID,
              record.status == .queued || record.status == .converting {
            do {
                var request = URLRequest(url: URL(string: Endpoints.ConvertedSong.detail(id: convertedSongID.uuidString))!)
                request.httpMethod = "GET"
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw VoiceConversionError.serverError("변환 상태 조회 실패")
                }

                let status = try decode(ConvertedSongStatusDTO.self, from: data)
                update(recordID: recordID) {
                    $0.status = mapStatus(status.status)
                    $0.errorMessage = status.errorMessage
                    $0.updatedAt = Date()
                }

                if status.status == "completed" || status.status == "failed" {
                    await syncConvertedSongsFromServer()
                    return
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                update(recordID: recordID) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                    $0.updatedAt = Date()
                }
                lastErrorMessage = error.localizedDescription
                return
            }
        }
    }

    private func resolveSourcePlaybackURL(for track: PlayableTrackDTO) async throws -> String {
        if let playbackUrl = track.playbackUrl, playbackUrl.hasPrefix("http") {
            return playbackUrl
        }
        if let fileUrl = track.fileUrl, fileUrl.hasPrefix("http") {
            return fileUrl
        }
        if let tracks = try? await JamendoService.shared.searchTracks(query: track.title, limit: 1),
           let url = tracks.first?.audiodownload {
            return url
        }
        throw VoiceConversionError.serverError("서버가 접근 가능한 원본 오디오 URL을 찾지 못했습니다.")
    }

    private func syncJobsFromConvertedSongs(_ songs: [ConvertedSongDTO]) {
        let existing = jobs
        var updated: [PreConversionJobRecord] = existing.map { record in
            guard let convertedSongID = record.convertedSongID,
                  let song = songs.first(where: { $0.id == convertedSongID }) else {
                return record
            }
            var next = record
            next.jobId = song.jobId
            next.status = mapStatus(song.status)
            next.errorMessage = song.errorMessage
            next.updatedAt = song.updatedAt ?? Date()
            return next
        }
        updated.sort { $0.updatedAt > $1.updatedAt }
        jobs = updated
        persistJobs()
    }

    private func playableTrack(from dto: ConvertedSongDTO) -> PlayableTrackDTO? {
        guard let url = dto.resultFileUrl else { return nil }
        return PlayableTrackDTO(
            id: dto.id,
            title: "\(dto.title) (Voice: \(dto.voiceName))",
            artistName: dto.artistName,
            playbackUrl: url,
            playbackStoreID: dto.sourceTrackId,
            isAIGenerated: true,
            duration: nil,
            fileUrl: url,
            artworkURL: URL(string: dto.artworkUrl ?? "")
        )
    }

    private func match(convertedSong: ConvertedSongDTO, track: PlayableTrackDTO, trackKey: String, voiceId: String? = nil) -> Bool {
        if let voiceId, convertedSong.voiceId != voiceId {
            return false
        }
        if let sourceTrackId = convertedSong.sourceTrackId,
           let playbackStoreID = track.playbackStoreID,
           sourceTrackId == playbackStoreID {
            return true
        }
        if let sourcePlaybackUrl = convertedSong.sourcePlaybackUrl,
           let playbackUrl = track.playbackUrl,
           sourcePlaybackUrl == playbackUrl {
            return true
        }
        return trackKey == makeSourceKey(sourceTrackId: convertedSong.sourceTrackId, sourcePlaybackUrl: convertedSong.sourcePlaybackUrl, title: convertedSong.title, artistName: convertedSong.artistName)
    }

    private func trackKey(for track: PlayableTrackDTO) -> String {
        makeSourceKey(sourceTrackId: track.playbackStoreID, sourcePlaybackUrl: track.playbackUrl, title: track.title, artistName: track.artistName)
    }

    private func makeSourceKey(sourceTrackId: String?, sourcePlaybackUrl: String?, title: String, artistName: String?) -> String {
        if let sourceTrackId, !sourceTrackId.isEmpty {
            return "track:\(sourceTrackId)"
        }
        if let sourcePlaybackUrl, !sourcePlaybackUrl.isEmpty {
            return "url:\(sourcePlaybackUrl)"
        }
        return "meta:\(normalize(title))::\(normalize(artistName ?? ""))"
    }

    private func convertedSongKey(_ song: ConvertedSongDTO) -> String {
        let sourceKey = makeSourceKey(
            sourceTrackId: song.sourceTrackId,
            sourcePlaybackUrl: song.sourcePlaybackUrl,
            title: song.title,
            artistName: song.artistName
        )
        return "\(sourceKey)::\(song.voiceId)"
    }

    private func preferenceScore(for song: ConvertedSongDTO) -> Int {
        let voiceName = song.voiceName.lowercased()
        return voiceName.hasSuffix(" full") ? 1 : 0
    }

    private func mapStatus(_ status: String) -> PreConversionJobStatus {
        switch status.lowercased() {
        case "queued": return .queued
        case "processing": return .converting
        case "completed": return .completed
        case "failed": return .failed
        default: return .failed
        }
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func upsert(_ record: PreConversionJobRecord) {
        jobs.removeAll { $0.id == record.id }
        jobs.insert(record, at: 0)
        jobs.sort { $0.updatedAt > $1.updatedAt }
        persistJobs()
    }

    private func update(recordID: UUID, mutate: (inout PreConversionJobRecord) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == recordID }) else { return }
        var record = jobs[index]
        mutate(&record)
        jobs[index] = record
        jobs.sort { $0.updatedAt > $1.updatedAt }
        persistJobs()
    }

    private func persistJobs() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        UserDefaults.standard.set(data, forKey: jobsKey)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let value = try? decoder.decode(T.self, from: data) {
            return value
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
