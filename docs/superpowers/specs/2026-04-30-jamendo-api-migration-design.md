# Jamendo API 전환 설계서

## 목적

Apple Music MusicKit 의존성을 완전히 제거하고 Jamendo API로 대체한다. 이를 통해 사용자 기기에 특정 음악 앱(Apple Music, Spotify 등) 설치 없이 독립적으로 음악 재생 및 음성 변환이 가능하도록 한다.

## 핵심 변경 사항

- MusicKit import 완전 제거
- Jamendo REST API 기반으로 곡 검색, 인기곡 차트, 아티스트 검색 구현
- 30초 프리뷰 → 풀트랙 재생으로 전환
- 음성 변환 시 풀트랙 오디오 데이터 다운로드 가능

## 아키텍처

```
현재: MusicKit → MusicCatalogSearchRequest → previewAssets → AVPlayer
변경: JamendoService → REST API → audio/audiodownload URL → AVPlayer
```

`JamendoService` 단일 서비스가 모든 Jamendo API 호출을 담당한다. 기존 `AudioManager`의 AVPlayer 재생 로직은 그대로 유지하고, 음원 소스만 Jamendo로 교체한다.

## 새로 생성할 파일

### JamendoModels.swift

Jamendo API 응답을 디코딩하기 위한 모델 정의.

```swift
struct JamendoTrack: Codable, Identifiable {
    let id: String
    let name: String           // 곡 제목
    let artist_name: String    // 아티스트 이름
    let album_name: String?
    let audio: String          // 스트리밍 URL
    let audiodownload: String  // 다운로드 URL
    let image: String          // 앨범 아트 URL
    let album_image: String?
    let duration: Int           // 초 단위
}

struct JamendoArtist: Codable, Identifiable {
    let id: String
    let name: String
    let image: String          // 아티스트 이미지 URL
}

struct JamendoResponse<T: Codable>: Codable {
    let headers: JamendoHeaders
    let results: [T]
}

struct JamendoHeaders: Codable {
    let status: String
    let code: Int
    let results_count: Int
}
```

### JamendoService.swift

Jamendo REST API 호출을 담당하는 서비스.

```swift
class JamendoService {
    static let shared = JamendoService()
    private let baseURL = "https://api.jamendo.com/v3.0"
    private let clientId = "YOUR_CLIENT_ID" // Endpoints에서 관리

    func searchTracks(query: String, limit: Int = 20) async throws -> [JamendoTrack]
    func getPopularTracks(limit: Int = 10) async throws -> [JamendoTrack]
    func searchArtists(name: String) async throws -> [JamendoArtist]
    func getArtistTracks(artistId: String) async throws -> [JamendoTrack]
    func downloadAudioData(from url: String) async throws -> Data
}
```

## 기존 파일 변경 사항

### Endpoints.swift

Jamendo API 설정 추가:

```swift
struct Jamendo {
    static let baseURL = "https://api.jamendo.com/v3.0"
    static let clientId = "YOUR_CLIENT_ID"
}
```

### AudioManager.swift

- `import MusicKit` 제거
- `playAppleMusicTrack(title:storeID:)` → Jamendo URL을 직접 받는 방식으로 변경
- MusicKit 관련 타입(MusicKit.Song, MusicCatalogSearchRequest 등) 참조 모두 제거
- `updateTrackMetadata(song:)` → Jamendo 트랙 정보 기반으로 변경
- AVPlayer 재생 로직(`playAIMusic`)은 그대로 유지

### HomeView.swift

- `fetchAppleMusicHitSongs()` → `JamendoService.shared.getPopularTracks()` 사용
- `fetchArtistArtworkURL()` → `JamendoService.shared.searchArtists()` 사용
- MusicKit 권한 요청(`MusicAuthorization.request()`) 제거
- 차트 데이터를 JamendoTrack 배열로 변환하여 기존 UI에 바인딩

### AddToPlaylist.swift

- `searchSongs()` → `JamendoService.shared.searchTracks()` 사용
- 검색 결과를 PlayableTrackDTO로 변환

### PlayerView.swift

- 음성 변환 시 Jamendo `audiodownload` URL로 풀트랙 Data 다운로드
- MusicKit import 및 관련 코드 제거

### HomeFeature.swift

- MusicKit 의존 코드 제거

### OnboardLoginTasteView.swift

- 아티스트 검색을 Jamendo API로 변경

## Jamendo API 엔드포인트 매핑

| 현재 MusicKit 기능 | Jamendo API 엔드포인트 |
|-------------------|----------------------|
| 곡 검색 (`MusicCatalogSearchRequest`) | `GET /v3.0/tracks/?search={query}&limit=20` |
| 인기곡 차트 (`MusicCatalogChartsRequest`) | `GET /v3.0/tracks/?order=popularity_week&limit=10` |
| 아티스트 검색 | `GET /v3.0/artists/?namesearch={name}` |
| 곡 ID로 조회 (`MusicCatalogResourceRequest`) | `GET /v3.0/tracks/?id={id}` |
| 프리뷰/재생 URL (`previewAssets`) | 응답의 `audio` 필드 (풀트랙 스트리밍) |
| 오디오 다운로드 | 응답의 `audiodownload` 필드 (풀트랙 다운로드) |
| 앨범 아트 | 응답의 `image` 또는 `album_image` 필드 |
| 아티스트 이미지 | 아티스트 응답의 `image` 필드 |

## 데이터 흐름

### 곡 검색 → 재생

1. 사용자가 검색어 입력
2. `JamendoService.searchTracks(query:)` 호출
3. 응답의 `JamendoTrack` 배열을 `PlayableTrackDTO`로 변환
4. 사용자가 곡 선택
5. `AudioManager.playAIMusic(from: track.audio, title:, artist:)` 호출
6. AVPlayer가 Jamendo 스트리밍 URL로 풀트랙 재생

### 음성 변환

1. 현재 재생 중인 곡의 `audiodownload` URL 사용
2. `JamendoService.downloadAudioData(from:)` 로 풀트랙 Data 다운로드
3. 다운로드한 Data를 LALAL.AI 음성 변환 파이프라인에 전달
4. 변환된 오디오를 AVPlayer로 재생

### 홈 화면 인기곡

1. `JamendoService.getPopularTracks(limit: 10)` 호출
2. JamendoTrack 배열을 기존 UI 모델로 변환
3. 앨범 아트는 `image` URL에서 AsyncImage로 로딩

## 에러 처리

- Jamendo API 실패 시 "음악을 불러올 수 없습니다" 사용자 표시
- 네트워크 없을 때 기존 AI 변환 곡(로컬/서버)은 계속 재생 가능
- API rate limit 초과 시 exponential backoff 재시도

## PlayableTrackDTO 변환

```swift
extension JamendoTrack {
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
            artworkURL: image
        )
    }
}
```

## 제거 대상

- `import MusicKit` (6개 파일)
- `MusicCatalogSearchRequest`, `MusicCatalogChartsRequest`, `MusicCatalogResourceRequest` 호출
- `MusicAuthorization.request()` 권한 요청
- `MPMusicPlayerController` 관련 코드 (Jamendo는 AVPlayer만 사용)
- `song.previewAssets` 참조
- `updateTrackMetadata(song: MusicKit.Song)` 메서드

## 테스트 범위

1. 곡 검색 → 재생 흐름
2. 홈 화면 인기곡 로딩
3. 음성 변환 (풀트랙 다운로드 → LALAL.AI)
4. 플레이리스트에 곡 추가
5. 아티스트 검색 및 이미지 로딩
6. 네트워크 에러 시 동작
