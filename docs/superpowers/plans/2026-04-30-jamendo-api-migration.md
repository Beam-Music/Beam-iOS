# Jamendo API Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Apple Music MusicKit with Jamendo API so the app plays full-length tracks independently without requiring any music app installed.

**Architecture:** Create a `JamendoService` that wraps Jamendo REST API calls. Replace all MusicKit references across 6 files. Remove `MPMusicPlayerController` and use `AVPlayer` exclusively for all playback. Existing `PlayableTrackDTO` and `AudioManager.playAIMusic()` are reused as-is.

**Tech Stack:** Swift, AVFoundation, URLSession, Jamendo REST API v3.0

**Spec:** `docs/superpowers/specs/2026-04-30-jamendo-api-migration-design.md`

---

### Task 1: Create Jamendo API Models

**Files:**
- Create: `BeamApp/Network/JamendoModels.swift`

- [ ] **Step 1: Create JamendoModels.swift with API response types**

```swift
//
//  JamendoModels.swift
//  BeamApp
//

import Foundation

struct JamendoResponse<T: Codable>: Codable {
    let headers: JamendoHeaders
    let results: [T]
}

struct JamendoHeaders: Codable {
    let status: String
    let code: Int
    let results_count: Int
}

struct JamendoTrack: Codable, Identifiable {
    let id: String
    let name: String
    let artist_name: String
    let album_name: String?
    let audio: String
    let audiodownload: String
    let image: String
    let album_image: String?
    let duration: Int

    func toPlayableTrackDTO() -> PlayableTrackDTO {
        PlayableTrackDTO(
            id: UUID(),
            title: name,
            artistName: artist_name,
            playbackUrl: audio,
            playbackStoreID: nil,
            isAIGenerated: false,
            duration: Double(duration),
            fileUrl: audio,
            artworkURL: URL(string: image)
        )
    }

    func toMusicSearchResult() -> MusicSearchResult {
        MusicSearchResult(
            id: id,
            title: name,
            artist: artist_name,
            artworkURL: URL(string: image),
            isExplicit: false
        )
    }
}

struct JamendoArtist: Codable, Identifiable {
    let id: String
    let name: String
    let image: String
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add BeamApp/Network/JamendoModels.swift
git commit -m "feat: add Jamendo API response models"
```

---

### Task 2: Create JamendoService

**Files:**
- Create: `BeamApp/Network/JamendoService.swift`
- Modify: `BeamApp/Network/Endpoints.swift`

- [ ] **Step 1: Add Jamendo config to Endpoints.swift**

Add inside `struct Endpoints`, after the existing `VoiceConversion` struct:

```swift
struct Jamendo {
    static let baseURL = "https://api.jamendo.com/v3.0"
    static let clientId = "YOUR_CLIENT_ID" // https://developer.jamendo.com 에서 발급
}
```

- [ ] **Step 2: Create JamendoService.swift**

```swift
//
//  JamendoService.swift
//  BeamApp
//

import Foundation

class JamendoService {
    static let shared = JamendoService()
    private let baseURL = Endpoints.Jamendo.baseURL
    private let clientId = Endpoints.Jamendo.clientId

    private init() {}

    // MARK: - Track Search

    func searchTracks(query: String, limit: Int = 20) async throws -> [JamendoTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "include", value: "musicinfo"),
            URLQueryItem(name: "audioformat", value: "mp3")
        ]
        return try await fetchTracks(from: components)
    }

    // MARK: - Popular Tracks (Chart replacement)

    func getPopularTracks(limit: Int = 10) async throws -> [JamendoTrack] {
        guard var components = URLComponents(string: "\(baseURL)/tracks/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "order", value: "popularity_week"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "audioformat", value: "mp3")
        ]
        return try await fetchTracks(from: components)
    }

    // MARK: - Artist Search

    func searchArtists(name: String, limit: Int = 10) async throws -> [JamendoArtist] {
        guard var components = URLComponents(string: "\(baseURL)/artists/") else {
            throw JamendoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "namesearch", value: name),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else {
            throw JamendoError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.serverError
        }
        let decoded = try JSONDecoder().decode(JamendoResponse<JamendoArtist>.self, from: data)
        return decoded.results
    }

    // MARK: - Download Audio Data (for voice conversion)

    func downloadAudioData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw JamendoError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.downloadFailed
        }
        return data
    }

    // MARK: - Private Helpers

    private func fetchTracks(from components: URLComponents) async throws -> [JamendoTrack] {
        guard let url = components.url else {
            throw JamendoError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw JamendoError.serverError
        }
        let decoded = try JSONDecoder().decode(JamendoResponse<JamendoTrack>.self, from: data)
        return decoded.results
    }
}

// MARK: - Errors

enum JamendoError: Error, LocalizedError {
    case invalidURL
    case serverError
    case downloadFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 URL입니다."
        case .serverError: return "서버 오류가 발생했습니다."
        case .downloadFailed: return "오디오 다운로드에 실패했습니다."
        case .noResults: return "검색 결과가 없습니다."
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add BeamApp/Network/JamendoService.swift BeamApp/Network/Endpoints.swift
git commit -m "feat: add JamendoService with search, chart, artist, and download APIs"
```

---

### Task 3: Replace MusicKit in AudioManager

**Files:**
- Modify: `BeamApp/AudioProcessing/AudioManager.swift`

This is the most critical change. We remove `import MusicKit`, remove `MPMusicPlayerController`, and replace `playAppleMusicTrack()` with a method that takes a Jamendo audio URL directly.

- [ ] **Step 1: Remove MusicKit import and MPMusicPlayerController**

Remove line `import MusicKit`.

Replace the `musicPlayerController` property and all its usages:

```swift
// REMOVE this line:
let musicPlayerController = MPMusicPlayerController.applicationQueuePlayer

// REMOVE setupNotifications() content related to MPMusicPlayerController:
// - .MPMusicPlayerControllerPlaybackStateDidChange observer
// - musicPlayerController.beginGeneratingPlaybackNotifications()
// Keep the AVAudioSession interruption observer.

// REMOVE handlePlaybackStateChange() method entirely

// REMOVE startTimerForMusicKit() method entirely
// REMOVE updateMusicKitPlaybackProgress() method entirely
// REMOVE checkForAppleMusicTrackCompletion() method entirely
```

- [ ] **Step 2: Simplify play/pause/stop to use AVPlayer only**

Replace `play()`:
```swift
func play() async {
    if !isPlayingMusic {
        avPlayer?.play()
        isPlayingMusic = true
    }
}
```

Replace `tryResume()`:
```swift
func tryResume() async -> Bool {
    if !isPlayingMusic {
        if let player = avPlayer, player.rate == 0 {
            player.play()
            isPlayingMusic = true
            return true
        }
    }
    return false
}
```

Replace `pause()`:
```swift
func pause() async {
    if isPlayingMusic {
        avPlayer?.pause()
        isPlayingMusic = false
    }
}
```

Replace `stop()`:
```swift
func stop() async {
    cleanupAIPlayback()
    currentTime = 0
    duration = 0
    isPlayingMusic = false
    isPlayingAIMusic = false
    currentTrackMetadata = (nil, nil, nil)
}
```

- [ ] **Step 3: Replace playAppleMusicTrack with playTrack**

Remove the entire `playAppleMusicTrack(title:storeID:)` method.

Replace `updateTrackMetadata(song: MusicKit.Song)` with:
```swift
private func updateTrackMetadata(title: String, artist: String, artworkURL: URL?) async {
    self.currentTrackMetadata = (title: title, artist: artist, albumArt: nil)

    if let artworkURL = artworkURL {
        Task.detached {
            var image: UIImage? = nil
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                image = UIImage(data: data)
            } catch {
                print("AudioManager Error: Failed loading artwork: \(error)")
            }
            await MainActor.run {
                if self.currentTrackMetadata.title == title {
                    self.currentTrackMetadata.albumArt = image
                }
            }
        }
    }
}
```

- [ ] **Step 4: Update init() to remove MusicKit-specific setup**

```swift
private init() {
    setupAudioSession()
    setupNotifications()
}
```

Remove `musicPlayerController.repeatMode = .none` and `handlePlaybackStateChange()` call from init.

- [ ] **Step 5: Update setupNotifications() to only keep interruption handler**

```swift
private func setupNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioInterruption),
        name: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance()
    )
}
```

- [ ] **Step 6: Update handleAudioInterruption to remove MPMusicPlayerController**

```swift
@objc private func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }

    switch type {
    case .began:
        avPlayer?.pause()
        isPlayingMusic = false
    case .ended:
        guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
            avPlayer?.play()
            isPlayingMusic = true
        }
    @unknown default:
        break
    }
}
```

- [ ] **Step 7: Update cleanup() to remove MPMusicPlayerController references**

```swift
func cleanup() {
    timer?.invalidate()
    timer = nil
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    removeAVPlayerObservers()
    removePeriodicTimeObserver()

    if avPlayer != nil {
        avPlayer?.pause()
        avPlayer?.replaceCurrentItem(with: nil)
        avPlayer = nil
    }
}
```

- [ ] **Step 8: Remove the `timer` property and related code**

Remove `private var timer: Timer?` property.
Remove `startTimerForMusicKit()`, `updateMusicKitPlaybackProgress()`, `checkForAppleMusicTrackCompletion()` methods entirely.

- [ ] **Step 9: Update seek() to AVPlayer only**

```swift
func seek(to seconds: Double) async {
    let targetTime = max(0, seconds)
    guard let player = avPlayer, let item = player.currentItem, item.status == .readyToPlay else {
        return
    }
    let time = CMTime(seconds: targetTime, preferredTimescale: 600)
    await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    self.currentTime = targetTime
}
```

- [ ] **Step 10: Update AudioManagerProtocol in PlayerReducer.swift**

In `PlayerReducer.swift`, update the protocol and remove `playAppleMusicTrack`:

```swift
protocol AudioManagerProtocol {
    func play() async
    func pause() async
    func stop() async
    func playAIMusic(from urlString: String, title: String, artist: String) async throws
    func isPlaying() async -> Bool
    func tryResume() async -> Bool
    func seek(to seconds: Double) async
    var isAIPlaying: Bool { get }
}
```

- [ ] **Step 11: Update PlayerReducer to use playAIMusic for all tracks**

In `PlayerReducer.swift`, replace all `playAppleMusicTrack(title:storeID:)` calls with `playAIMusic(from:title:artist:)`. The track's `fileUrl` or `playbackUrl` provides the Jamendo audio URL:

Replace the pattern:
```swift
// OLD:
try await audioManager.playAppleMusicTrack(title: track.title, storeID: track.playbackStoreID)
```

With:
```swift
// NEW:
if let audioURL = track.fileUrl ?? track.playbackUrl {
    try await audioManager.playAIMusic(
        from: audioURL,
        title: track.title,
        artist: track.artistName ?? "Unknown Artist"
    )
} else {
    await send(.playbackError("No audio URL available"))
}
```

This pattern appears in the following cases within `PlayerReducer`:
- `.nextTrack` (non-AI track branch)
- `.previousTrack` (non-AI track branch)
- `.updateCurrentIndex` (non-AI track branch, appears twice)
- `.startPlayback` (non-AI track branch)

- [ ] **Step 12: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 13: Commit**

```bash
git add BeamApp/AudioProcessing/AudioManager.swift BeamApp/Feature/Player/PlayerReducer.swift
git commit -m "refactor: remove MusicKit from AudioManager, use AVPlayer exclusively"
```

---

### Task 4: Replace MusicKit in HomeView

**Files:**
- Modify: `BeamApp/Feature/Home/HomeView.swift`

- [ ] **Step 1: Remove MusicKit import**

Remove `import MusicKit`.

- [ ] **Step 2: Replace MusicSearchService to use JamendoService**

Replace the `MusicSearchService` class (around line 49-68):

```swift
class MusicSearchService {
    func searchMusic(query: String) async throws -> [MusicSearchResult] {
        let tracks = try await JamendoService.shared.searchTracks(query: query, limit: 25)
        return tracks.map { $0.toMusicSearchResult() }
    }
}
```

- [ ] **Step 3: Replace fetchAppleMusicHitSongs()**

Replace the method body (around line 390-414):

```swift
private func fetchAppleMusicHitSongs() async {
    do {
        let tracks = try await JamendoService.shared.getPopularTracks(limit: 10)
        let results = tracks.map { $0.toMusicSearchResult() }
        await MainActor.run {
            hitSongs = results
        }
    } catch {
        print("Failed to fetch popular tracks: \(error)")
    }
}
```

- [ ] **Step 4: Replace fetchArtistArtworkURL()**

Replace the method (around line 508-517):

```swift
private func fetchArtistArtworkURL(artist: String) async -> URL? {
    do {
        let artists = try await JamendoService.shared.searchArtists(name: artist, limit: 1)
        if let first = artists.first, let url = URL(string: first.image) {
            return url
        }
    } catch {
        print("Failed to fetch artist artwork: \(error)")
    }
    return nil
}
```

- [ ] **Step 5: Remove MusicAuthorization.request() calls**

Find and remove any `MusicAuthorization.request()` calls. These are no longer needed since Jamendo doesn't require Apple Music authorization.

- [ ] **Step 6: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add BeamApp/Feature/Home/HomeView.swift
git commit -m "refactor: replace MusicKit with Jamendo in HomeView"
```

---

### Task 5: Replace MusicKit in PlayerView

**Files:**
- Modify: `BeamApp/Feature/Player/PlayerView.swift`

- [ ] **Step 1: Remove MusicKit import**

Remove `import MusicKit`.

- [ ] **Step 2: Replace fetchApplePreviewURL()**

Replace the `fetchApplePreviewURL` method (around line 1440-1454) with a Jamendo-based version that returns the full track audio URL:

```swift
private func fetchAudioURL(reducerTrack: PlayableTrackDTO?, fallbackTitle: String?) async throws -> URL? {
    // First try to use the track's existing audio URL
    if let urlString = reducerTrack?.fileUrl ?? reducerTrack?.playbackUrl,
       let url = URL(string: urlString) {
        return url
    }

    // Fallback: search Jamendo by title
    let searchTerm: String
    if let title = reducerTrack?.title {
        searchTerm = title
    } else if let fallback = fallbackTitle {
        searchTerm = fallback
    } else {
        return nil
    }

    let tracks = try await JamendoService.shared.searchTracks(query: searchTerm, limit: 1)
    guard let track = tracks.first, let url = URL(string: track.audiodownload) else {
        return nil
    }
    return url
}
```

- [ ] **Step 3: Update all call sites of fetchApplePreviewURL**

Find all calls to `fetchApplePreviewURL` in PlayerView and replace with `fetchAudioURL`. The signature change is:
- Old: `fetchApplePreviewURL(reducerTrack:fallbackTitle:)`
- New: `fetchAudioURL(reducerTrack:fallbackTitle:)`

- [ ] **Step 4: Remove any remaining MusicKit type references**

Remove any `MusicCatalogResourceRequest`, `MusicCatalogSearchRequest`, `MusicItemID`, `MusicKit.Song` references.

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add BeamApp/Feature/Player/PlayerView.swift
git commit -m "refactor: replace MusicKit with Jamendo in PlayerView"
```

---

### Task 6: Replace MusicKit in AddToPlaylist, HomeFeature, OnboardLoginTasteView

**Files:**
- Modify: `BeamApp/Feature/Player/AddToPlaylist.swift`
- Modify: `BeamApp/Feature/Home/HomeFeature.swift`
- Modify: `BeamApp/Feature/LoginFeature/Onboard/OnboardLoginTasteView.swift`

- [ ] **Step 1: Update AddToPlaylist.swift**

Remove `import MusicKit`. The `searchSongs()` function already calls `MusicSearchService().searchMusic()` which we updated in Task 4 to use Jamendo. No other changes needed unless there are direct MusicKit references.

- [ ] **Step 2: Update HomeFeature.swift**

Remove `import MusicKit`. Check for any direct MusicKit type references and remove them.

- [ ] **Step 3: Update OnboardLoginTasteView.swift**

Remove `import MusicKit`.

Replace the `fetchArtistImageURL` function (around line 418-431):

```swift
func fetchArtistImageURL(artistName: String, completion: @escaping (URL?) -> Void) {
    Task {
        do {
            let artists = try await JamendoService.shared.searchArtists(name: artistName, limit: 1)
            if let first = artists.first, let url = URL(string: first.image) {
                completion(url)
            } else {
                completion(nil)
            }
        } catch {
            completion(nil)
        }
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add BeamApp/Feature/Player/AddToPlaylist.swift BeamApp/Feature/Home/HomeFeature.swift BeamApp/Feature/LoginFeature/Onboard/OnboardLoginTasteView.swift
git commit -m "refactor: remove MusicKit from AddToPlaylist, HomeFeature, OnboardLoginTasteView"
```

---

### Task 7: Update voice conversion to use Jamendo full track download

**Files:**
- Modify: `BeamApp/Feature/Player/VoiceConversionService.swift`
- Modify: `BeamApp/Feature/Player/PlayerView.swift` (voice conversion section)

- [ ] **Step 1: Update voice conversion flow in PlayerView**

In PlayerView, find the voice conversion code that downloads audio for LALAL.AI processing. Replace the Apple Music preview URL fetch with Jamendo `audiodownload` URL:

Where the code fetches audio data for voice conversion, use:
```swift
// Get full track audio data from Jamendo download URL
let audioURL: String
if let downloadURL = currentTrack?.playbackUrl {
    audioURL = downloadURL
} else {
    throw VoiceConversionError.invalidAudioData
}
let audioData = try await JamendoService.shared.downloadAudioData(from: audioURL)
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add BeamApp/Feature/Player/VoiceConversionService.swift BeamApp/Feature/Player/PlayerView.swift
git commit -m "feat: use Jamendo full track download for voice conversion"
```

---

### Task 8: Final cleanup and verification

**Files:**
- All modified files

- [ ] **Step 1: Verify no MusicKit references remain**

Run: `grep -rn 'import MusicKit' BeamApp/ --include='*.swift'`
Expected: No matches

Run: `grep -rn 'MusicCatalog\|MusicAuthorization\|MPMusicPlayerController\|MusicItemID\|previewAssets' BeamApp/ --include='*.swift'`
Expected: No matches (except possibly in comments or backup files)

- [ ] **Step 2: Full build**

Run: `xcodebuild -project BeamApp.xcodeproj -scheme BeamApp -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E '(error:|BUILD)'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit all remaining changes**

```bash
git add -A
git commit -m "chore: final cleanup - remove all MusicKit references"
```

- [ ] **Step 4: Push**

```bash
git push origin dev
```
