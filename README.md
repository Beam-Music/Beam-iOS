# Beam Music App 🎵

Beam은 AI 음악 생성과 Apple Music 통합을 제공하는 iOS 음악 스트리밍 앱입니다.

## 아키텍처 및 디자인 패턴

- **The Composable Architecture (TCA)** 사용

  - 상태 관리와 사이드 이펙트를 효과적으로 처리
  - 모듈화된 기능 구현과 테스트 용이성 제공
  - 단방향 데이터 흐름으로 예측 가능한 상태 변화

- **Feature별 디렉토리 구성**
  ```
  BeamApp/
  ├── Feature/
  │   ├── Home/
  │   ├── Player/
  │   ├── Library/
  │   └── Generator/
  ├── Network/
  │   ├── APIClient
  │   ├── Endpoints
  │   └── DTO/
  └── Common/
      ├── Extensions
      └── Utils
  ```

## Git-flow 전략

- **브랜치 구성**

  - `main`: 프로덕션 릴리즈
  - `develop`: 개발 브랜치
  - `feature/*`: 새로운 기능 개발
  - `bugfix/*`: 버그 수정
  - `release/*`: 릴리즈 준비

- **커밋 메시지 컨벤션**
  ```
  feat: 새로운 기능 추가
  fix: 버그 수정
  docs: 문서 수정
  style: 코드 포맷팅
  refactor: 코드 리팩토링
  test: 테스트 코드
  chore: 빌드 업무 수정
  ```

## Code Style Guide

- **Swift API Design Guidelines** 준수
- **SwiftLint** 사용으로 일관된 코드 스타일 유지
- **네이밍 컨벤션**
  - 클래스/구조체: UpperCamelCase
  - 변수/함수: lowerCamelCase
  - 상수: UPPER_SNAKE_CASE

## 리소스 관리

- **Assets**

  - 이미지: SF Symbols 우선 사용
  - 컬러: Asset Catalog에서 관리
  - 폰트: 시스템 폰트 사용

- **문자열**
  - Localizable.strings 파일에서 중앙 관리
  - 하드코딩된 문자열 지양

## 주요 기능

- Apple Music 통합
- AI 음악 생성 및 재생
- 플레이리스트 관리
- 실시간 음악 재생

## 개발 환경 설정

1. Xcode 15.0 이상
2. iOS 16.0 이상
3. Swift 5.9 이상

## 필수 설정

```bash

# 의존성 설치
cd Beam-iOS
swift package resolve

# 환경 변수 설정
cp .env.example .env
# .env 파일에 필요한 API 키 입력
```

## API 키 설정

다음 API 키들이 필요합니다:

- `JWT_SECRET`: JWT 토큰 생성용
- `MUSIC_KIT_KEY`: Apple Music API 접근용

## 환경 변수 설정

1. 프로젝트 루트에 `.env` 파일 생성:

```bash
# API Keys
JWT_SECRET=your_jwt_secret_here
MUSIC_KIT_KEY=your_music_kit_key_here

API_VERSION=v1

# Feature Flags
ENABLE_AI_MUSIC=true
ENABLE_APPLE_MUSIC=true

# Analytics
ENABLE_ANALYTICS=false
```

2. 환경 변수 사용:

```swift
// Config.swift에서 환경 변수 로드
struct Config {
    static let jwtSecret = ProcessInfo.processInfo.environment["JWT_SECRET"]
    static let musicKitKey = ProcessInfo.processInfo.environment["MUSIC_KIT_KEY"]
    // ...
}
```

## 프로젝트 구조

```
BeamApp/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── AppReducer.swift
├── Feature/
│   ├── Home/
│   │   ├── HomeFeature.swift
│   │   ├── HomeView.swift
│   │   └── HomeReducer.swift
│   ├── Player/
│   │   ├── PlayerFeature.swift
│   │   ├── PlayerView.swift
│   │   └── PlayerReducer.swift
│   └── Auth/
│       ├── LoginFeature.swift
│       └── SignupFeature.swift
├── Network/
│   ├── APIClient.swift
│   ├── Endpoints.swift
│   └── DTO/
│       ├── PlaylistItem.swift
│       └── TokenResponse.swift
└── Common/
    ├── Extensions/
    │   └── View+Extensions.swift
    └── Utils/
        └── TokenStorage.swift
```

## 코드 스타일 가이드

### 네이밍

```swift
// 타입은 UpperCamelCase
struct PlaylistItem { }
class AudioPlayer { }
enum PlaybackState { }

// 변수와 함수는 lowerCamelCase
var currentSong: Song
func playSong() { }

// 상수는 UPPER_CASE
let MAX_RETRY_COUNT = 3
let API_BASE_URL = "https://api.example.com"
```

### 주석

```swift
/// 문서화 주석은 /// 사용
/// - Parameters:
///   - id: 곡 ID
///   - completion: 완료 핸들러
func fetchSong(id: String, completion: @escaping (Result<Song, Error>) -> Void)

// 일반 주석은 // 사용 (뒤에 공백 필수)
// TODO: 에러 처리 추가 필요
// FIXME: 메모리 누수 의심
```

## 라이센스

이 프로젝트는 MIT 라이센스를 따릅니다.
