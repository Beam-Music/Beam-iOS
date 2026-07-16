# Beam Music iOS

Beam Music iOS는 AI 보이스 컨버전 기반 음악 플레이어 프로토타입입니다. 사용자는 음악을 탐색하고 재생하면서 원하는 AI 보이스를 선택해 미리듣기 또는 전체 곡 변환을 요청할 수 있습니다.

> iOS 앱은 아티스트 음성, 음원 권리, 배포 심사 등 법적 접촉성 이슈 때문에 공개 배포하지 않습니다. 실제 동작 데모는 배포된 웹 데모에서 확인할 수 있습니다.

- Web demo: https://beam-music.kimjiha1112.chatgpt.site
- iOS demo video: [docs/assets/beam-ios-demo.mov](docs/assets/beam-ios-demo.mov)

## 현재 구현 요약

- SwiftUI 기반 iOS 앱 화면 구성
- The Composable Architecture(TCA) 기반 Feature 단위 상태 관리
- 로그인/회원가입 및 온보딩 플로우
- 홈 화면 음악 탐색, 트렌딩/검색 기반 트랙 목록
- 플레이어, 미니 플레이어, 재생 제어, 트랙 이동
- AI 보이스 선택, 프리뷰 변환, 전체 트랙 변환 요청
- 변환된 곡 저장 및 `Songs I Converted` 라이브러리 화면
- 사용자 플레이리스트 조회, 생성, 상세 화면, 곡 추가
- Beam SVC 서버 연동을 위한 Voice Conversion Provider 추상화
- 변환 warmup/pre-conversion 매니저를 통한 선행 변환, 재개, 캐싱
- 네트워크/저전력 조건 기반 warmup 제어

## 전체 아키텍처

```text
Beam-iOS
  |
  | 1. login, playlists, converted songs, metadata
  v
beam-svc-server / app API
  |
  | 2. voice list, voice conversion, async job status
  v
RVC 기반 SVC pipeline
  |
  | 3. converted audio result
  v
Beam-iOS Player / Library

beam-music-web-demo
  |
  | deployed browser demo for public review
  v
same deployed Beam backend and SVC flow
```

현재 iOS 앱은 `Endpoints`에서 `BEAM_API_BASE_URL`, `BEAM_SVC_BASE_URL`을 환경 변수 또는 `Info.plist` 값으로 읽고, 값이 없으면 개발용 기본 URL을 사용합니다. 음성 변환은 앱 내부 호출부가 특정 벤더에 직접 묶이지 않도록 `VoiceConversionProvider` 프로토콜 뒤에 감춰져 있습니다.

## iOS 앱 구조

```text
BeamApp/
├── App/                       # 앱 진입점, asset catalog
├── DataFlow/                  # AppReducer
├── Feature/
│   ├── Home/                  # 음악 탐색, 트렌딩, 검색, 재생 시작
│   ├── Player/                # 메인 플레이어, AI/REMIX 토글, 보이스 변환
│   ├── MiniPlayer/            # 하단 미니 플레이어
│   ├── Library/               # 플레이리스트, 변환된 곡 목록
│   ├── Playlist/              # 플레이리스트 상세
│   ├── LoginFeature/          # 로그인, 회원가입, 온보딩
│   ├── Conversion/            # pre-conversion, warmup, 캐시/작업 상태
│   ├── Setting/               # 사용자 설정
│   └── Tab/                   # 탭 내비게이션
├── Network/
│   ├── Endpoints.swift        # API base URL 및 endpoint 정의
│   ├── APIClient.swift        # 서버 API 호출
│   ├── VoiceConversionClient.swift
│   ├── AudiusService.swift
│   └── DTO/                   # API DTO
├── AudioProcessing/           # 오디오 재생/처리 매니저
├── DesignSystem/              # 버튼, 네비게이션, 텍스트/컬러 스타일
├── Security/                  # Keychain
└── Database/                  # 토큰/로컬 저장 모델
```

## 핵심 기능

### 음악 탐색과 재생

- Audius API와 Apple/iTunes preview URL을 이용한 검색/트렌딩 곡 탐색
- `AudioManager` 기반 재생, 일시정지, 이전/다음 트랙 이동
- 메인 플레이어와 미니 플레이어 상태 공유
- 앨범 아트, 진행률, 재생 상태 UI 제공

### AI 보이스 컨버전

- 서버에서 사용 가능한 보이스 목록 조회
- 선택한 보이스로 현재 트랙 preview segment 변환
- 전체 곡 변환은 async job 형태로 요청하고 진행률/stage를 표시
- 변환 결과를 로컬 레코드 및 서버 converted song 목록과 동기화
- `Songs I Converted` 화면에서 변환된 결과 재생

### Pre-conversion / Warmup

- 다음 트랙 또는 현재 트랙을 선행 변환해 TTFAT(Time To First AI Track)를 줄이는 구조
- Wi-Fi 또는 유선 네트워크이며 저전력 모드가 아닐 때만 warmup 허용
- 동일 트랙/보이스 조합이 이미 변환된 경우 중복 작업 방지
- 앱 재시작 후 pending job 재개 및 서버 상태 동기화

### 사용자와 라이브러리

- 로그인, 회원가입, 온보딩 화면
- 사용자 플레이리스트 조회 및 생성
- 플레이리스트 상세 곡 조회와 재생
- 플레이어에서 현재 곡을 플레이리스트에 추가

## Beam SVC 연동

iOS 앱은 Beam SVC 서버의 다음 API를 사용합니다.

```text
GET  /ai-convert/health
GET  /ai-convert/voices
POST /ai-convert/voice-conversion
GET  /ai-convert/jobs/:jobId
```

동기 preview 변환은 audio bytes를 바로 받아 재생하고, 긴 전체 곡 변환은 `return_job=true` 기반 async job으로 처리합니다. 자세한 API 형태는 [docs/BEAM_SVC_API_SPEC.md](docs/BEAM_SVC_API_SPEC.md)를 참고합니다.

## 배포와 데모 정책

- `beam-svc-server`는 GPU 기반 RVC/SVC 파이프라인을 제공하는 서버입니다.
- `beam-music-web-demo`는 공개 확인용 브라우저 데모로 배포되어 있습니다.
- iOS 앱은 권리/심사 리스크 때문에 공개 배포하지 않고, 앱 동작은 데모 영상과 웹 데모로 확인합니다.

공개 확인 경로:

- Web demo: https://beam-music.kimjiha1112.chatgpt.site
- iOS demo video: [docs/assets/beam-ios-demo.mov](docs/assets/beam-ios-demo.mov)

## 개발 환경

- Xcode 15 이상
- iOS 16 이상
- Swift 5.9 이상

프로젝트 열기:

```bash
open BeamApp.xcodeproj
```

Swift Package 의존성 갱신:

```bash
swift package resolve
```

## 환경 변수 및 설정

앱은 실행 환경 또는 `Info.plist`에서 다음 값을 읽습니다.

```text
BEAM_API_BASE_URL
BEAM_SVC_BASE_URL
JAMENDO_CLIENT_ID
```

예시:

```text
BEAM_API_BASE_URL=http://127.0.0.1:8080
BEAM_SVC_BASE_URL=http://127.0.0.1:8081
```

API 키와 외부 서비스 토큰은 저장소에 커밋하지 않습니다.

## 관련 문서

- [docs/BEAM_SVC_API_SPEC.md](docs/BEAM_SVC_API_SPEC.md)
- [docs/BEAM_SVC_PIPELINE_DESIGN.md](docs/BEAM_SVC_PIPELINE_DESIGN.md)
- [docs/SVC_MIGRATION.md](docs/SVC_MIGRATION.md)
- [docs/remote-svc-deployment.md](docs/remote-svc-deployment.md)
- [docs/2026-06-24-preconversion-api-plan.md](docs/2026-06-24-preconversion-api-plan.md)

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.
