# Self-hosted Singing Voice Conversion

## Goal
Use Beam SVC backend only, without Kits AI or LALAL.AI at runtime.

## iOS changes
- Force provider to `beamSVC`
- Load voice list from `GET /ai-convert/voices`
- Convert via `POST /ai-convert/voice-conversion`
- Keep legacy Kits/LALAL code only for reference during migration

## Backend contract
### `GET /ai-convert/voices`
Response:
```json
{
  "voices": [
    {
      "voiceId": "taylor_swift_singer",
      "name": "Taylor Swift Style",
      "category": "Western Pop Female",
      "description": "...",
      "preview_url": null,
      "language": ["en"]
    }
  ]
}
```

### `POST /ai-convert/voice-conversion`
Multipart fields:
- `source_audio`
- `voiceId`
- `voiceType` (optional)
- `language`
- `preserve_melody`

Success:
- raw audio bytes

Failure:
```json
{ "error": "..." }
```

## Recommended backend pipeline
1. Decode upload
2. Optional vocal isolation
3. F0 extraction / melody preservation
4. SVC inference
5. Loudness normalize
6. Encode result and return audio bytes

## Suggested open-source stack
- UVR / Demucs: vocal separation
- RMVPE / CREPE: pitch extraction
- RVC or so-vits-svc: singing voice conversion
- ffmpeg: encode/mux/post-process

## Next backend tasks
- Add job queue for long conversions
- Add progress endpoint
- Cache voice metadata
- Add timeout / file-size guards
- Add test voice models for default voices
