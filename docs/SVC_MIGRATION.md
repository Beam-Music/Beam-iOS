# Singing Voice Conversion 자체 구현 마이그레이션

> 작성일: 2026-05-13
> 목적: lalal.ai 의존성을 제거하고 자체 SVC(Demucs + RVC) 파이프라인으로 이전

---

## 🎯 최종 목표

| 항목 | AS-IS | TO-BE |
|------|-------|-------|
| 음성 변환 엔진 | lalal.ai Voice Change API (분당 과금) | Beam 자체 백엔드 (Demucs + RVC v2) |
| 보이스 라인업 | lalal 고정 9종 (ALEX_KAYE 등) | 무제한 + 사용자 보이스 학습 |
| 변환 단가 | ~$0.02~0.05/분 | GPU 시간당 ~$0.5 (30초 곡 ≈ $0.001~0.003) |
| 지연 | 30~90초 | 5~15초 |
| 통제력 | API 응답에만 의존 | F0, 인덱스 비율, 포먼트 등 풀 제어 |

---

## 🏗️ 자체 SVC 표준 파이프라인

```
입력 mp3
   ↓
1. Demucs v4 (htdemucs) → vocals.wav + instrumental.wav
   ↓
2. ContentVec (HuBERT-soft)  → 음소(content) 임베딩
3. RMVPE                      → F0 contour
4. Speaker embedding (RVC index) → 타깃 가수 정체성
   ↓
5. RVC v2 Acoustic Model → mel-spectrogram
   ↓
6. NSF-HiFi-GAN Vocoder → 변환된 보컬 waveform
   ↓
7. Re-mix (변환된 보컬 + 원본 반주) → 최종 mp3
```

추천 OSS:
- 보컬 분리: **Demucs v4 (htdemucs)** — 1티어 품질
- 콘텐츠 인코더: **ContentVec**, HuBERT-soft
- F0 추출: **RMVPE** (노래용 최강), CREPE 백업
- Acoustic + Vocoder: **RVC v2** (https://github.com/RVC-Project) — 가수 1명 10~30분 데이터로 학습 가능

---

## 📂 현재 코드 상태 (중요!)

### ⚠️ 코드 중복 / 빌드 미포함 파일들

`BeamApp.xcodeproj/project.pbxproj` 확인 결과, **디스크에는 있지만 빌드 타겟에 포함되어 있지 않은 파일**:

| 파일 | 상태 | 비고 |
|------|------|------|
| `BeamApp/Network/LalalAIClient.swift` | ❌ 빌드 제외 | |
| `BeamApp/Network/LalalAIService.swift` | ❌ 빌드 제외 | |
| `BeamApp/Network/VoiceConversionClient.swift` | ❌ 빌드 제외 | **TCA Dependency로 자체 백엔드 호출 로직이 이미 작성돼 있음** |
| `BeamApp/Network/Models/VoiceConversionModels.swift` | ❌ 빌드 제외 | |
| `BeamApp/Feature/Player/VoiceConversionService.swift` | ❌ 빌드 제외 | |
| `BeamApp/Feature/Player/VoiceSelectionSheet.swift` | ❌ 빌드 제외 | |
| `BeamApp/Feature/Player/PlayerView.swift` | ✅ **빌드 포함** | 위 파일들의 내용이 **인라인 복붙**돼 있음 (line 14~700) |

즉 **실제로 동작하는 lalal.ai 클라이언트 코드는 PlayerView.swift 안에 통째로 있음**.

### 호출부 (PlayerView.swift)
```swift
// line 12
private let voiceConversionService = VoiceConversionService()  // 같은 파일 line 213의 class

// line 1284 (preview)
let convertedAudioData = try await voiceConversionService.performLalalAIVoiceChange(
    audioData: audioData,
    voiceId: "ALEX_KAYE"
)

// line 1389~1397 (실제 사용)
func convertVoice(voiceId: String, voiceType: String, ...) -> Data {
    let isSingerVoice = voiceId.contains("_singer") || voiceType == "singer"
    if isSingerVoice {
        return try await voiceConversionService.performLalalAIVoiceChange(audioData: audioData, voiceId: voiceId)
    } else {
        return try await voiceConversionService.performLalalAIVoiceChange(audioData: audioData, voiceId: voiceId)
    }
}
```

### 백엔드 엔드포인트 (이미 정의됨, `Endpoints.swift`)
```swift
struct VoiceConversion {
    static let list = "\(baseURL)/ai-convert/voices"
    static let convert = "\(baseURL)/ai-convert/voice-conversion"
}
```
→ **iOS 외부 인터페이스는 그대로 두고 백엔드 내부만 교체하면 클라이언트 코드 변경 최소화**.

---

## 🗺️ 단계별 로드맵

### Phase 0: iOS Provider 추상화 ⬅️ **현재 단계**
- `VoiceConversionProvider` 프로토콜 정의
- `LalalAIVoiceConversionProvider` (기존 코드 래핑)
- `BeamSVCVoiceConversionProvider` (`/ai-convert/voice-conversion` 호출)
- `VoiceConversionConfig`로 런타임 스위칭
- 호출부 변경

### Phase 1: 보컬 분리 자체화 (1~2주)
- 서버에 Demucs htdemucs 도커 컨테이너
- 입력 mp3 → vocals/instrumental 분리 엔드포인트
- lalal 크레딧 사용량 큰 폭 감소

### Phase 2: RVC 추론 서버 (2~4주)
- RVC-WebUI 기반 FastAPI 래퍼
- Celery 큐로 비동기 처리
- 진행률 SSE/WebSocket

### Phase 3: 가수 모델 학습 파이프라인 (4~8주)
- 데이터 수집 (라이선스 확보 필수)
- 전처리 (UVR, 슬라이서)
- RVC v2 학습 (RTX 4090에서 ~2~6시간)
- 평가 (MOS, SECS, F0 RMSE)

### Phase 4: 품질·지연 최적화
- 짧은 변환 온디바이스 처리 (CoreML)
- 결과 캐싱 (track_id + voice_id)
- 청크 스트리밍

### Phase 5: 사용자 보이스 등록 (UGC) — 차별화
- 짧은 가창 30~60초로 자동 학습
- "내 목소리로 노래" UX

---

## ✅ Phase 0 작업 계획 (다음에 이어서 할 일)

### 옵션 A: 점진적 (추천)
PlayerView.swift 내부에서 추상화. pbxproj 안 건드림.

1. PlayerView.swift 상단에 `VoiceConversionProvider` 프로토콜 추가
2. 인라인 `class VoiceConversionService`를 `LalalAIVoiceConversionProvider`로 이름 변경 + 프로토콜 채택
3. 같은 파일에 `BeamSVCVoiceConversionProvider` 추가
   - 백엔드 호출 로직은 `BeamApp/Network/VoiceConversionClient.swift`(미사용 파일)의 `performVoiceConversion` 함수를 복사
4. `VoiceConversionConfig.useBeamSVC` 플래그 (UserDefaults or BuildConfig)
5. 호출부 3군데 (line 1284, 1395, 1397) → `provider.convert(...)`로 변경

### 옵션 B: 파일 분리 (다음 PR)
디스크의 미사용 파일 살리고 pbxproj 등록. Xcode UI에서 수동 추가 권장.

---

## 🔑 핵심 파일 위치

- `BeamApp/Feature/Player/PlayerView.swift` — **실제 lalal 코드 인라인** (line 14~700)
- `BeamApp/Feature/Player/PlayerView.swift` line 12, 1284, 1389~1397 — 호출부
- `BeamApp/Network/Endpoints.swift` — 자체 백엔드 엔드포인트 정의됨
- `BeamApp/Network/VoiceConversionClient.swift` — **미사용이지만 자체 백엔드 호출 코드 이미 작성됨** (이식 소스로 사용)
- `BeamApp.xcodeproj/project.pbxproj` — Synchronized group 미사용, 수기 등록 필요

---

## 🚀 다음 세션 시작 방법

새 세션에서 아래처럼 말하면 즉시 이어갈 수 있음:

> "docs/SVC_MIGRATION.md 읽고 Phase 0 옵션 A로 진행해줘"
