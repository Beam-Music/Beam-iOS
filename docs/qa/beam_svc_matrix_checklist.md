# Beam SVC Matrix QA Checklist

## Goal

Verify that every available Beam SVC voice converts reliably across:

- same gender + same genre
- same gender + different genre
- different gender + same genre
- different gender + different genre

## Setup

1. Start the Beam SVC server.
2. Confirm `GET /ai-convert/health` returns `ok=true`.
3. Use the direct Beam SVC URL for QA, not an app/Nest proxy, unless the proxy supports `POST /voice-conversion`, `GET /jobs/:id`, and `GET /results/:id`.
4. Prepare a source manifest CSV with columns:
   `path,title,artist,gender,genre`
5. Include at least:
   - male vocal pop
   - female vocal pop
   - male rap
   - female R&B
   - high vocal range
   - low vocal range
   - dense instrumental mix

## Run

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --trim-duration 8
```

Use server registry defaults instead of current iOS app pitch overrides:

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --trim-duration 8 \
  --server-defaults
```

Limit to a small smoke subset:

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --voices ariana_grande,taylor_swift_singer,dionn_v1_singing \
  --max-cases 6
```

Continue after failures only when intentionally collecting a full failure matrix:

```bash
python3 scripts/beam_svc_matrix_qa.py \
  --base-url http://213.173.110.175:36936 \
  --manifest docs/qa/beam_svc_source_manifest.example.csv \
  --trim-duration 8 \
  --keep-going
```

## Review Tags

Fill `review` and `notes` in the generated `results.csv`.

- `pass`: converted vocal is audible and musically usable
- `no_vocal`: instrumental only or vocal nearly absent
- `too_quiet`: vocal exists but is buried
- `pitch_wrong`: obvious octave/key issue
- `robotic`: severe artifacts
- `distorted`: clipping or broken audio
- `off_timing`: vocal timing drift
- `bad_separation`: source vocal separation failed
- `playback_issue`: output file is fine but app playback fails

## Pass Criteria

- Every voice completes at least one same-gender and one different-gender case.
- Every voice completes at least one same-genre and one different-genre case when source coverage exists.
- Output duration roughly matches the requested trim duration.
- Output file size is not empty or suspiciously tiny.
- Converted vocal is audible in manual listening.
- Failures have a reproducible source track, target voice, and review tag.

## Follow-Up Fix Order

1. `no_vocal`
2. job failure or timeout
3. `pitch_wrong`
4. `too_quiet`
5. severe artifacts
