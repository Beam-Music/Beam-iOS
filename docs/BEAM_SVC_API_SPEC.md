# Beam SVC Server API Spec

## Base
- `GET /ai-convert/health`
- `GET /ai-convert/voices`
- `POST /ai-convert/voice-conversion`
- `GET /ai-convert/jobs/:jobId`

## 1. Health
### Request
`GET /ai-convert/health`

### Response
```json
{
  "ok": true,
  "service": "beam-svc",
  "version": "0.1.0",
  "gpu": true,
  "modelsLoaded": true
}
```

## 2. Voice list
### Request
`GET /ai-convert/voices`

### Response
```json
{
  "voices": [
    {
      "voiceId": "taylor_swift_singer",
      "name": "Taylor Swift Style",
      "category": "Western Pop Female",
      "description": "RVC v2 singer model",
      "preview_url": null,
      "language": ["en"],
      "voiceType": "singer",
      "model": {
        "engine": "rvc",
        "sampleRate": 48000,
        "f0": true,
        "indexRatio": 0.75,
        "protect": 0.33
      }
    }
  ],
  "total_count": 1
}
```

## 3. Voice conversion
### Request
`POST /ai-convert/voice-conversion`

### Multipart fields
- `source_audio`: required, file
- `voiceId`: required, string
- `voiceType`: optional, `default|singer|custom`
- `language`: optional, default `en`
- `preserve_melody`: optional, `true|false`, default `true`
- `return_job`: optional, `true|false`, default `false`
- `mix_with_instrumental`: optional, `true|false`, default `true`
- `output_format`: optional, `mp3|wav|m4a`, default `mp3`
- `pitch_shift`: optional, integer, default `0`
- `index_ratio`: optional, float, default model preset
- `protect`: optional, float, default model preset
- `filter_radius`: optional, integer, default `3`

### Success: sync audio bytes
- `200 OK`
- `Content-Type: audio/mpeg|audio/wav|audio/mp4`
- body: audio bytes

### Success: async job mode
If `return_job=true`
```json
{
  "jobId": "svc_01j123...",
  "status": "queued"
}
```

### Error
```json
{
  "error": "voice_not_found",
  "message": "Unknown voiceId: taylor_swift_singer"
}
```

## 4. Job status
### Request
`GET /ai-convert/jobs/:jobId`

### Response
```json
{
  "jobId": "svc_01j123...",
  "status": "processing",
  "progress": 62,
  "stage": "svc_inference",
  "resultUrl": null,
  "error": null
}
```

## Validation
- max file size: 25MB
- max duration: 60s sync / 300s async
- allowed mime: `audio/mpeg`, `audio/wav`, `audio/x-wav`, `audio/mp4`, `audio/m4a`

## Pipeline stages
1. decode
2. normalize
3. vocal_separation
4. f0_extract
5. content_extract
6. svc_inference
7. remix
8. encode

## Voice model registry
Recommended per voice metadata:
```json
{
  "voiceId": "taylor_swift_singer",
  "engine": "rvc",
  "modelPath": "models/rvc/taylor/model.pth",
  "indexPath": "models/rvc/taylor/added.index",
  "featureExtractor": "hubert-base",
  "f0Method": "rmvpe",
  "sampleRate": 48000,
  "indexRatio": 0.75,
  "protect": 0.33,
  "filterRadius": 3,
  "mixRate": 0.9
}
```
