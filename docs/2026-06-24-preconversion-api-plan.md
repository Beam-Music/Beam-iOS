# 2026-06-24 선변환 API/모델 정리

## 목표
- iOS에서 플레이리스트 곡을 선변환 요청한다.
- 변환은 Beam-Server 기준으로 사용자 자산으로 저장된다.
- 실제 긴 작업은 beam-svc-server job 으로 처리한다.
- iOS는 Beam-Server만 신뢰하고, beam-svc-server는 내부 서비스로 둔다.

---

## 권장 구조

### iOS -> Beam-Server
- 변환 요청 생성
- 내 변환 목록 조회
- 특정 변환 상태 조회
- 완료 결과 playback URL 조회

### Beam-Server -> beam-svc-server
- 실제 음성 변환 job 생성
- job status polling
- 결과 파일 확보
- 사용자별 메타데이터 저장

---

## 데이터 모델

### converted_song
- id: UUID
- user_id: UUID
- source_track_id: String?
- source_playback_url: String?
- title: String
- artist_name: String?
- artwork_url: String?
- voice_id: String
- voice_name: String
- voice_type: String?
- status: queued | processing | completed | failed
- beam_svc_job_id: String?
- result_file_url: String?
- error_message: String?
- created_at: Date
- updated_at: Date

### 중복 키
- unique(user_id, source_track_id or source_playback_url, voice_id)

---

## Beam-Server API 제안

### 1. 변환 요청 생성
`POST /api/converted-songs`

body:
```json
{
  "sourceTrackId": "audius-track-id-or-null",
  "sourcePlaybackUrl": "https://...",
  "title": "Fix You",
  "artistName": "Coldplay",
  "artworkUrl": "https://...",
  "voiceId": "dionn_v1_singing",
  "voiceName": "Dionn V1 Singing",
  "voiceType": "singer"
}
```

response:
```json
{
  "id": "uuid",
  "status": "queued",
  "jobId": "svc_xxx",
  "isDuplicate": false
}
```

중복이면:
- 기존 queued/processing/completed 레코드 반환
- `isDuplicate: true`

### 2. 내 변환 목록 조회
`GET /api/converted-songs`

query:
- `status`
- `voiceId`
- `limit`
- `offset`

response:
```json
[
  {
    "id": "uuid",
    "title": "Fix You",
    "artistName": "Coldplay",
    "voiceId": "dionn_v1_singing",
    "voiceName": "Dionn V1 Singing",
    "status": "completed",
    "resultFileUrl": "https://...",
    "createdAt": "...",
    "updatedAt": "..."
  }
]
```

### 3. 단건 상태 조회
`GET /api/converted-songs/{id}`

response:
```json
{
  "id": "uuid",
  "status": "processing",
  "progress": 45,
  "stage": "converting",
  "resultFileUrl": null,
  "errorMessage": null
}
```

### 4. 재생용 목록
`GET /api/converted-songs/playable`
- completed 상태만 반환
- iOS에서 바로 `PlayableTrackDTO`로 매핑 가능하게 응답해도 좋음

---

## beam-svc-server 사용 규칙

### 요청
`POST /ai-convert/voice-conversion`
- `source_audio`
- `voiceId`
- `voiceType`
- `return_job=true`

### 상태
`GET /ai-convert/jobs/{jobId}`

### 결과
`GET /ai-convert/results/{jobId}`

---

## 상태 매핑 규칙

### beam-svc-server -> Beam-Server
- queued -> queued
- processing -> processing
- completed -> completed
- failed -> failed

### Beam-Server -> iOS
- queued -> 대기중
- processing -> 변환중
- completed -> 완료
- failed -> 실패

---

## iOS 적용 순서
1. 현재 로컬 선변환 UI 유지
2. Beam-Server API 붙이기
3. 로컬 저장 대신 서버 메타 기준 목록화
4. 앱 재설치 후에도 서버 목록 복원
5. 필요 시 로컬 캐시 + 서버 메타 혼합

---

## 이번 구현 범위 메모
- 지금 iOS에는 로컬 pre-conversion manager가 먼저 들어가 있음
- 다음 단계에서 이 매니저를 Beam-Server backed store로 교체/확장하면 됨
