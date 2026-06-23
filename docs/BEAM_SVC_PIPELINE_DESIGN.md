# Beam SVC Pipeline Design

## Goal
Implement self-hosted singing voice conversion without Kits AI or LALAL.AI.

## Recommended stack
- API: FastAPI
- Queue: Celery or RQ
- Broker: Redis
- Separation: Demucs (`htdemucs`)
- F0: RMVPE
- Content encoder: HuBERT / ContentVec
- SVC: RVC v2 first, so-vits-svc optional fallback/experiment
- Post-process: ffmpeg, pyloudnorm
- Storage: local disk or S3-compatible object storage

## Recommended runtime split
### API server
- validate request
- create temp work dir
- sync mode for <= 30s
- async job mode for > 30s or queue pressure

### GPU worker
- preload HuBERT / RMVPE / RVC model
- reuse model cache by `voiceId`
- process one job per GPU by default

## RVC-based inference flow
1. Decode input to mono/stereo WAV 44.1k or 48k
2. Loudness normalize input
3. Separate vocals/instrumental via Demucs
4. Run RMVPE to extract F0 from vocal stem
5. Run HuBERT/ContentVec for content features
6. Load target RVC checkpoint + FAISS index
7. Infer converted vocal
8. Post-process: denoise/declick optional
9. Remix with instrumental if `mix_with_instrumental=true`
10. Encode to requested format

## so-vits-svc option
Use when:
- you want stronger singing timbre transfer
- you control training per-voice carefully
- latency can be slightly higher

Tradeoff vs RVC:
- pros: strong singing-specific identity in some voices
- cons: training/serving complexity often higher, community deployment patterns vary more

## Recommendation
- **Prod v1:** RVC v2 only
- **R&D branch:** so-vits-svc A/B quality comparison on same dataset

## Model packaging
Per voice:
- `model.pth`
- `added.index`
- `meta.json`

Example `meta.json`:
```json
{
  "voiceId": "taylor_swift_singer",
  "displayName": "Taylor Swift Style",
  "engine": "rvc",
  "sampleRate": 48000,
  "f0Method": "rmvpe",
  "indexRatio": 0.75,
  "protect": 0.33,
  "filterRadius": 3,
  "mixRate": 0.9,
  "languages": ["en"]
}
```

## Suggested directory layout
```text
server/
  app/
    main.py
    api/
      voices.py
      convert.py
      jobs.py
    services/
      demucs_service.py
      rmvpe_service.py
      rvc_service.py
      remix_service.py
      registry.py
    models/
      schemas.py
  model_registry/
    voices.json
  weights/
    hubert/
    rmvpe/
    rvc/
      taylor_swift_singer/
        model.pth
        added.index
        meta.json
```

## Performance targets
- 30s song sync conversion: 5~15s target on 4090/L4 class GPU
- queue warm start: < 2s overhead
- cached model switch: < 1s if same engine family

## Safety / ops
- limit per-request duration and size
- hash input + params for cache key
- auto cleanup temp dirs
- watermark internal previews if needed
- audit voice/model provenance and consent

## Implementation phases
### Phase A
- sync API
- local temp storage
- single worker
- RVC only

### Phase B
- queue + status API
- result storage
- model registry admin

### Phase C
- batching/caching
- A/B presets
- optional so-vits-svc worker lane
