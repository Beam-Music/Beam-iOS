# RunPod GPU Training Handoff

Use this when direct SSH from the iOS/Codex agent is blocked by host key or auth errors.

## Goal

Train `chris_martin` longer on RunPod GPU, deploy it to `beam-svc-server`, and make voice conversion use GPU only.

## Current State

- App points to RunPod SVC: `http://213.173.110.175:36936`
- RunPod currently exposes 8 voices:
  - `dionn_v1_singing`
  - `freya_idol`
  - `taylor_swift_singer`
  - `the_weeknd`
  - `ariana_grande`
  - `dua_lipa`
  - `lil_wayne`
  - `drake`
- Local `beam-svc-server` has a smoke-test `chris_martin` model trained for 1 epoch.
- Local Chris Martin model works only with index disabled:
  - `indexRatio: 0.0`
  - `indexPath: null`
- Local QA output:
  - `/tmp/beam_chris_martin_preview_5s.mp3`
  - `/tmp/beam_svc_matrix_qa_chris_local/summary.md`

## GPU-Only Runtime Requirement

The server must run with:

```bash
BEAM_RVC_DEVICE=cuda:0
BEAM_RVC_IS_HALF=true
BEAM_REQUIRE_GPU=true
```

Expected `/ai-convert/health` fields:

```json
{
  "gpu": true,
  "device": "cuda:0",
  "requireGpu": true,
  "modelsLoaded": true
}
```

If `gpu` is false, do not continue QA. Fix CUDA/PyTorch first.

## Files To Deploy

From local machine:

```text
/Users/anonymous/Desktop/Code/beamMusic/beam-svc-server/weights/rvc/chris_martin/model.pth
/Users/anonymous/Desktop/Code/beamMusic/beam-svc-server/model_registry/voices.json
/Users/anonymous/Desktop/Code/beamMusic/beam-svc-server/app/settings.py
/Users/anonymous/Desktop/Code/beamMusic/beam-svc-server/app/services/pipeline.py
/Users/anonymous/Desktop/Code/beamMusic/beam-svc-server/app/services/demucs_service.py
```

Target on RunPod:

```text
/workspace/beamMusic/beam-svc-server/weights/rvc/chris_martin/model.pth
/workspace/beamMusic/beam-svc-server/model_registry/voices.json
```

Also sync the server code changes above or pull the equivalent patch.

## Long Training Plan

Use the existing Coldplay/Chris Martin vocal stems:

```text
Coldplay - Fix You (One Love Manchester).mp3_main_vocal.flac
Coldplay - feelslikeimfallinginlove (Official Audio).mp3_main_vocal.flac
```

Recommended RVC settings:

```text
exp_dir: chris_martin
sample rate: 40k
version: v2
f0: true
f0 method: rmvpe_gpu
gpu: 0
batch size: start 8, reduce to 4 if OOM
epochs: 100-200 for first production candidate
save every epoch: 20
pretrained G: assets/pretrained_v2/f0G40k.pth
pretrained D: assets/pretrained_v2/f0D40k.pth
```

After training, export:

```text
assets/weights/chris_martin.pth
```

Train index too, but keep runtime index disabled unless QA proves it is stable:

```text
logs/chris_martin/added_chris_martin_v2_ivf_flat_nprobe_1.index
```

## Registry Entry

Use this stable default:

```json
{
  "voiceId": "chris_martin",
  "name": "Chris Martin",
  "category": "Celebrity",
  "description": "Chris Martin / Coldplay-style male rock-pop vocal",
  "preview_url": null,
  "language": ["en"],
  "voiceType": "singer",
  "model": {
    "engine": "rvc",
    "sampleRate": 40000,
    "f0": true,
    "indexRatio": 0.0,
    "protect": 0.33,
    "filterRadius": 3,
    "mixRate": 0.9,
    "defaultPitchShift": 0,
    "modelPath": "weights/rvc/chris_martin/model.pth",
    "indexPath": null
  }
}
```

## Verification

1. Restart SVC.
2. Check health:

```bash
curl -s http://127.0.0.1:18081/ai-convert/health
curl -s http://213.173.110.175:36936/ai-convert/health
```

3. Confirm voice list includes `chris_martin`.
4. Run 5-second QA:

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --voices chris_martin \
  --max-cases 1 \
  --trim-duration 5 \
  --out-dir /tmp/beam_svc_matrix_qa_chris_runpod
```

5. Run all production voices:

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --voices dionn_v1_singing,freya_idol,taylor_swift_singer,the_weeknd,ariana_grande,dua_lipa,lil_wayne,drake,chris_martin \
  --trim-duration 5 \
  --out-dir /tmp/beam_svc_matrix_qa_all_runpod
```

## Pass Criteria

- `/ai-convert/health` reports `gpu: true`.
- `chris_martin` appears in `/ai-convert/voices`.
- Chris Martin 5-second conversion returns HTTP 200.
- Output has audible converted vocal, no no-vocal regression.
- App can select and convert with `chris_martin`.
