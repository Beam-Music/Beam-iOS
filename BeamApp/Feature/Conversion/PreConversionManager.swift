import Foundation
import Network
import SwiftUI

enum PreConversionJobStatus: String, Codable, Equatable {
    case queued
    case converting
    case completed
    case failed

    var label: String {
        switch self {
        case .queued: return "Queued"
        case .converting: return "Converting"
        case .completed: return "Done"
        case .failed: return "Failed"
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
    /// 현재 warmup이 실제로 허용된 상태인지 (Wi-Fi + not low-power)
    @Published private(set) var warmupEnabled: Bool = true

    private let jobsKey = "pre_conversion.jobs"
    private let preferredVoiceKey = "pre_conversion.preferred_voice_id"

    // NWPathMonitor는 nonisolated로 관리 (MainActor 외부)
    private nonisolated let monitor = NWPathMonitor()
    private nonisolated let monitorQueue = DispatchQueue(label: "beam.preconv.network", qos: .utility)
    /// 최신 네트워크 경로 (monitor callback에서 업데이트)
    private var latestPath: NWPath?

    // MARK: - Proactive warmup (Phase 1-3)

    /// 트랙별 활성 warmup Task — trackKey → Task
    private var activeWarmupTasks: [String: Task<Void, Never>] = [:]
    /// 다음 트랙 warmup용 voiceId 오버라이드 (User에게 선택된 voice, nil이면 preferredVoice)
    @Published var warmupVoiceIdOverride: String?

    private init() {
        loadPersistedState()
        loadPreferredVoiceId()
        startNetworkMonitor()
        Task {
            await loadAvailableVoices()
            await syncConvertedSongsFromServer()
            await resumePendingJobsIfNeeded()
        }
    }

    // MARK: - Proactive Warmup

    /// 현재 재생 중인 트랙 warmup. 이미 진행 중이면 skip.
    func warmup(track: PlayableTrackDTO) async {
        let key = trackKey(for: track)
        guard TokenStorage.shared.fetchToken() != nil else {
            print("⏭️ [PreConv] warmup skipped: not logged in")
            return
        }
        guard let voice = warmupVoiceIdOverride.flatMap({ overrideId in
            availableVoices.first(where: { $0.id == overrideId })
        }) ?? preferredVoice() else {
            print("⏭️ [PreConv] warmup skipped: no preferred voice")
            return
        }
        let path = latestPath
        if let path, !isWarmupConditionsMet(path: path) {
            print("⏭️ [PreConv] warmup skipped: network unsuitable")
            return
        }
        if let existing = latestConvertedTrack(for: track, voiceId: voice.id) {
            print("✅ [PreConv] warmup skipped: already converted (track=\(track.title) voice=\(voice.name))")
            return
        }
        if activeWarmupTasks[key] != nil {
            print("⏭️ [PreConv] warmup skipped: already warming up (track=\(track.title))")
            return
        }
        print("🔥 [PreConv] warmup started track=\(track.title) voice=\(voice.name)")
        let task = Task { [weak self] in
            guard let self else { return }
            await self.enqueue(track: track, voice: voice)
            await MainActor.run {
                self.activeWarmupTasks.removeValue(forKey: key)
            }
        }
        activeWarmupTasks[key] = task
    }

    /// 다음 트랙을 미리 warmup. playlist의 다음 index.
    func warmupNextTrack(track: PlayableTrackDTO) async {
        let key = trackKey(for: track)
        guard activeWarmupTasks[key] == nil else {
            print("⏭️ [PreConv] warmupNextTrack: already warming up")
            return
        }
        // 이미 Done된 변환이면 skip
        if let voice = warmupVoiceIdOverride.flatMap({ overrideId in
            availableVoices.first(where: { $0.id == overrideId })
        }) ?? preferredVoice(),
           latestConvertedTrack(for: track, voiceId: voice.id) != nil {
            print("✅ [PreConv] warmupNextTrack: already converted")
            return
        }
        print("🔮 [PreConv] warmupNextTrack track=\(track.title)")
        await warmup(track: track)
    }

    /// 현재 트랙의 warmup Cancel (트랙 변경 시)
    func cancelWarmup(for track: PlayableTrackDTO) {
        let key = trackKey(for: track)
        guard let task = activeWarmupTasks.removeValue(forKey: key) else { return }
        task.cancel()
        print("🛑 [PreConv] warmup cancelled track=\(track.title)")
        // jobs에서 queued 상태인 레코드 제거
        jobs.removeAll { $0.trackKey == key && $0.status == .queued }
        persistJobs()
    }

    /// 모든 활성 warmup Cancel
    func cancelAllWarmups() {
        for (_, task) in activeWarmupTasks {
            task.cancel()
        }
        activeWarmupTasks.removeAll()
        jobs.removeAll { $0.status == .queued }
        persistJobs()
        print("🛑 [PreConv] all warmups cancelled")
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestPath = path
                let allowed = self.isWarmupConditionsMet(path: path)
                self.warmupEnabled = allowed
                if allowed {
                    print("📶 [PreConv] Warmup enabled (WiFi + normal power)")
                } else {
                    print("📶 [PreConv] Warmup paused (cellular or low-power mode)")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private nonisolated func isWarmupConditionsMet(path: NWPath) -> Bool {
        // Wi-Fi 또는 유선 연결만 허용 (셀룰러 제외)
        let isWifi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
        // 저전력 모드 체크 (ProcessInfo는 main thread에서만 안전하지만, 이 값은 read-only snapshot)
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        return isWifi && !isLowPower
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
        warmupVoiceIdOverride = voice.id
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
        do {
            guard let url = URL(string: Endpoints.VoiceConversion.list) else {
                throw VoiceConversionError.serverError("Invalid voice list URL")
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VoiceConversionError.serverError("Failed to load the voice list.")
            }
            struct VoiceListPayload: Decodable { let voices: [VoiceInfo] }
            let decoded = try JSONDecoder()
                .decode(VoiceListPayload.self, from: data)
                .voices
                .filter { $0.voiceType == "singer" }
            if !decoded.isEmpty {
                availableVoices = decoded
            }
        } catch {
            if availableVoices.isEmpty {
                availableVoices = VoiceInfo.beamSVCFallbackVoices.filter { $0.voiceType == "singer" }
            }
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
        return nil
    }

    func latestJob(for track: PlayableTrackDTO) -> PreConversionJobRecord? {
        let key = trackKey(for: track)
        return jobs
            .filter { $0.trackKey == key }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func jobForVoice(_ voice: VoiceInfo, track: PlayableTrackDTO) -> PreConversionJobRecord? {
        let key = trackKey(for: track)
        return jobs
            .filter { $0.trackKey == key && $0.voiceId == voice.id }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func conversionStatusForVoice(_ voice: VoiceInfo, track: PlayableTrackDTO) -> PreConversionJobStatus? {
        if let record = jobForVoice(voice, track: track) {
            return record.status
        }
        if latestConvertedTrack(for: track, voiceId: voice.id) != nil {
            return .completed
        }
        return nil
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
                throw VoiceConversionError.serverError("Login is required.")
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
                throw VoiceConversionError.serverError(serverErrorMessage(from: data, fallback: "Conversion request failed"))
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

            let songs = deduplicatedConvertedSongs(
                try decode([ConvertedSongDTO].self, from: data)
                .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            )
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
                    throw VoiceConversionError.serverError(serverErrorMessage(from: data, fallback: "Failed to check conversion status"))
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
        throw VoiceConversionError.serverError("Could not find a source audio URL accessible by the server.")
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

    private func deduplicatedConvertedSongs(_ songs: [ConvertedSongDTO]) -> [ConvertedSongDTO] {
        var seenKeys = Set<String>()
        var unique: [ConvertedSongDTO] = []

        for song in songs {
            let key = convertedSongKey(song)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            unique.append(song)
        }

        return unique
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

    private func serverErrorMessage(from data: Data, fallback: String) -> String {
        struct VaporError: Decodable {
            let error: Bool?
            let reason: String?
        }

        if let decoded = try? JSONDecoder().decode(VaporError.self, from: data),
           let reason = decoded.reason,
           !reason.isEmpty {
            if reason.localizedCaseInsensitiveContains("could not connect to the server") ||
                reason.localizedCaseInsensitiveContains("connection refused") ||
                reason.localizedCaseInsensitiveContains("Beam SVC") {
                return "Beam SVC server is not reachable. Update BEAM_SVC_URL to the active RunPod endpoint and try again."
            }
            if reason == "Not Found" {
                return "Converted-song endpoint was not found on the running Vapor server. Restart the current beam-server build."
            }
            return reason
        }

        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            return body
        }
        return fallback
    }
}
