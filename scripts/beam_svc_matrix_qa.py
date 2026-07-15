#!/usr/bin/env python3
"""
Run Beam SVC matrix QA across source tracks and target voices.

Outputs:
- voices.json: voice registry snapshot
- results.csv: machine-readable conversion results
- summary.md: human review checklist and failure summary
- outputs/<source>/<voice>.mp3: converted audio files
"""

from __future__ import annotations

import argparse
import csv
import json
import mimetypes
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


APP_PITCH_OVERRIDES = {
    "ariana_grande": 0,
    "taylor_swift_singer": 0,
}

MAX_ERROR_CHARS = 1200

VOICE_TRAITS = {
    "ariana_grande": {"gender": "female", "genre": "pop"},
    "dua_lipa": {"gender": "female", "genre": "pop"},
    "chris_martin": {"gender": "male", "genre": "rock-pop"},
    "taylor_swift_singer": {"gender": "female", "genre": "pop"},
    "freya_idol": {"gender": "female", "genre": "idol"},
    "dionn_v1_singing": {"gender": "male", "genre": "pop"},
    "the_weeknd": {"gender": "male", "genre": "rnb"},
    "drake": {"gender": "male", "genre": "rap"},
    "lil_wayne": {"gender": "male", "genre": "rap"},
}


@dataclass
class SourceTrack:
    path: Path
    title: str
    artist: str
    gender: str
    genre: str


@dataclass
class CaseResult:
    source_title: str
    source_path: str
    source_gender: str
    source_genre: str
    voice_id: str
    voice_name: str
    target_gender: str
    target_genre: str
    combination: str
    pitch_shift: str
    status: str
    job_id: str
    duration_seconds: str
    size_bytes: str
    mean_volume_db: str
    max_volume_db: str
    output_path: str
    error: str
    review: str = ""
    notes: str = ""


def slug(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "-" for ch in value)
    return "-".join(part for part in cleaned.split("-") if part)[:80] or "untitled"


def compact_error(error: BaseException | str) -> str:
    message = str(error).replace("\r", " ").strip()
    lines = [line.strip() for line in message.splitlines() if line.strip()]
    compact = " | ".join(lines)
    if len(compact) > MAX_ERROR_CHARS:
        return compact[:MAX_ERROR_CHARS] + "...[truncated]"
    return compact


def http_json(url: str, timeout: int = 30) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def multipart_post(url: str, fields: dict[str, str], file_field: str, file_path: Path, timeout: int) -> dict[str, Any]:
    boundary = f"Boundary-{uuid.uuid4().hex}"
    chunks: list[bytes] = []

    def add_field(name: str, value: str) -> None:
        chunks.append(f"--{boundary}\r\n".encode())
        chunks.append(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        chunks.append(str(value).encode())
        chunks.append(b"\r\n")

    for key, value in fields.items():
        if value != "":
            add_field(key, value)

    content_type = mimetypes.guess_type(file_path.name)[0] or "audio/mpeg"
    chunks.append(f"--{boundary}\r\n".encode())
    chunks.append(
        f'Content-Disposition: form-data; name="{file_field}"; filename="{file_path.name}"\r\n'.encode()
    )
    chunks.append(f"Content-Type: {content_type}\r\n\r\n".encode())
    chunks.append(file_path.read_bytes())
    chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())

    request = urllib.request.Request(
        url,
        data=b"".join(chunks),
        method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read()
        return json.loads(payload.decode("utf-8"))


def download(url: str, output_path: Path, timeout: int) -> None:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        output_path.write_bytes(response.read())


def run_capture(command: list[str]) -> str:
    completed = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return completed.stdout + completed.stderr


def probe_duration(path: Path) -> str:
    if shutil.which("ffprobe") is None:
        return ""
    output = run_capture(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ]
    ).strip()
    try:
        return f"{float(output):.2f}"
    except ValueError:
        return ""


def probe_volume(path: Path) -> tuple[str, str]:
    if shutil.which("ffmpeg") is None:
        return "", ""
    output = run_capture(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"])
    mean_volume = ""
    max_volume = ""
    for line in output.splitlines():
        if "mean_volume:" in line:
            mean_volume = line.split("mean_volume:", 1)[1].strip().split()[0]
        if "max_volume:" in line:
            max_volume = line.split("max_volume:", 1)[1].strip().split()[0]
    return mean_volume, max_volume


def load_manifest(path: Path) -> list[SourceTrack]:
    rows: list[SourceTrack] = []
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            audio_path = Path(row["path"]).expanduser()
            rows.append(
                SourceTrack(
                    path=audio_path,
                    title=row.get("title") or audio_path.stem,
                    artist=row.get("artist", ""),
                    gender=(row.get("gender") or "unknown").lower(),
                    genre=(row.get("genre") or "unknown").lower(),
                )
            )
    return rows


def load_sources(args: argparse.Namespace) -> list[SourceTrack]:
    sources: list[SourceTrack] = []
    if args.manifest:
        sources.extend(load_manifest(Path(args.manifest).expanduser()))
    for audio in args.audio:
        path = Path(audio).expanduser()
        sources.append(SourceTrack(path=path, title=path.stem, artist="", gender="unknown", genre="unknown"))

    missing = [str(source.path) for source in sources if not source.path.exists()]
    if missing:
        raise SystemExit(f"Missing audio files:\n" + "\n".join(missing))
    if not sources:
        raise SystemExit("Provide at least one --audio file or --manifest CSV.")
    return sources


def voice_gender(voice: dict[str, Any]) -> str:
    return VOICE_TRAITS.get(voice.get("voiceId", ""), {}).get("gender", "unknown")


def voice_genre(voice: dict[str, Any]) -> str:
    return VOICE_TRAITS.get(voice.get("voiceId", ""), {}).get("genre", "unknown")


def combination(source: SourceTrack, target_gender: str, target_genre: str) -> str:
    gender_part = "same_gender" if source.gender != "unknown" and source.gender == target_gender else "different_gender"
    genre_part = "same_genre" if source.genre != "unknown" and source.genre == target_genre else "different_genre"
    if source.gender == "unknown" or target_gender == "unknown":
        gender_part = "unknown_gender"
    if source.genre == "unknown" or target_genre == "unknown":
        genre_part = "unknown_genre"
    return f"{gender_part}+{genre_part}"


def selected_voices(all_voices: list[dict[str, Any]], requested: str) -> list[dict[str, Any]]:
    if not requested:
        return all_voices
    wanted = {item.strip() for item in requested.split(",") if item.strip()}
    return [voice for voice in all_voices if voice.get("voiceId") in wanted]


def convert_case(
    base_url: str,
    source: SourceTrack,
    voice: dict[str, Any],
    output_path: Path,
    args: argparse.Namespace,
) -> tuple[str, str, str]:
    voice_id = voice["voiceId"]
    fields = {
        "voiceId": voice_id,
        "voiceType": voice.get("voiceType") or "singer",
        "language": "en",
        "preserve_melody": "true",
        "mix_with_instrumental": "true",
        "output_format": "mp3",
        "trim_start": str(args.trim_start),
        "trim_duration": str(args.trim_duration),
        "return_job": "true",
    }
    if not args.server_defaults and voice_id in APP_PITCH_OVERRIDES:
        fields["pitch_shift"] = str(APP_PITCH_OVERRIDES[voice_id])

    response = multipart_post(
        f"{base_url}/ai-convert/voice-conversion",
        fields,
        "source_audio",
        source.path,
        timeout=args.submit_timeout,
    )
    job_id = response.get("jobId", "")
    if not job_id:
        raise RuntimeError(f"Missing jobId in response: {response}")

    deadline = time.time() + args.job_timeout
    last_status = ""
    while time.time() < deadline:
        status = http_json(f"{base_url}/ai-convert/jobs/{job_id}", timeout=30)
        last_status = json.dumps(status, ensure_ascii=False)
        state = status.get("status")
        progress = status.get("progress")
        stage = status.get("stage")
        print(f"    job {job_id}: {state} {progress}% {stage or ''}".rstrip(), flush=True)
        if state == "completed":
            download(f"{base_url}/ai-convert/results/{job_id}", output_path, timeout=args.download_timeout)
            return job_id, fields.get("pitch_shift", ""), ""
        if state == "failed":
            raise RuntimeError(status.get("error") or last_status)
        time.sleep(args.poll_interval)

    raise TimeoutError(f"Timed out waiting for {job_id}. Last status: {last_status}")


def write_results_csv(path: Path, results: list[CaseResult]) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(CaseResult.__dataclass_fields__.keys()))
        writer.writeheader()
        for result in results:
            writer.writerow(result.__dict__)


def write_summary(path: Path, results: list[CaseResult], args: argparse.Namespace) -> None:
    total = len(results)
    passed = sum(1 for result in results if result.status == "completed")
    failed = total - passed
    by_combo: dict[str, list[CaseResult]] = {}
    for result in results:
        by_combo.setdefault(result.combination, []).append(result)

    lines = [
        "# Beam SVC Matrix QA Summary",
        "",
        f"- Generated: {datetime.now().isoformat(timespec='seconds')}",
        f"- Base URL: `{args.base_url}`",
        f"- Trim: start `{args.trim_start}s`, duration `{args.trim_duration}s`",
        f"- Pitch policy: `{'server defaults' if args.server_defaults else 'app defaults'}`",
        f"- Completed: `{passed}/{total}`",
        f"- Failed: `{failed}/{total}`",
        "",
        "## Combination Coverage",
        "",
    ]

    for combo in sorted(by_combo):
        combo_results = by_combo[combo]
        combo_passed = sum(1 for result in combo_results if result.status == "completed")
        lines.append(f"- `{combo}`: `{combo_passed}/{len(combo_results)}` completed")

    lines.extend(
        [
            "",
            "## Manual Listening Checklist",
            "",
            "For each completed output, fill `review` and `notes` in `results.csv`.",
            "",
            "- `pass`: converted vocal is audible and musically usable",
            "- `no_vocal`: instrumental only or vocal nearly absent",
            "- `too_quiet`: vocal exists but is buried",
            "- `pitch_wrong`: obvious octave/key issue",
            "- `robotic`: severe artifacts",
            "- `distorted`: clipping or broken audio",
            "- `off_timing`: vocal timing drift",
            "- `bad_separation`: source vocal separation failed",
            "- `playback_issue`: output file is fine but app playback fails",
            "",
            "## Failures",
            "",
        ]
    )

    failures = [result for result in results if result.status != "completed"]
    if not failures:
        lines.append("- None")
    else:
        for result in failures:
            lines.append(f"- `{result.source_title}` -> `{result.voice_id}`: {result.error}")

    path.write_text("\n".join(lines) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Beam SVC source x voice matrix QA.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8081")
    parser.add_argument("--manifest", help="CSV with path,title,artist,gender,genre columns.")
    parser.add_argument("--audio", action="append", default=[], help="Audio file. Can be repeated.")
    parser.add_argument("--voices", default="", help="Comma-separated voiceId allowlist. Default: all voices.")
    parser.add_argument("--out-dir", default=f"/tmp/beam_svc_matrix_qa_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
    parser.add_argument("--trim-start", type=float, default=0.0)
    parser.add_argument("--trim-duration", type=float, default=8.0)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument("--submit-timeout", type=int, default=120)
    parser.add_argument("--download-timeout", type=int, default=120)
    parser.add_argument("--job-timeout", type=int, default=900)
    parser.add_argument("--max-cases", type=int, default=0, help="Stop after N cases. 0 means no limit.")
    parser.add_argument("--server-defaults", action="store_true", help="Do not send app pitch overrides.")
    parser.add_argument("--keep-going", action="store_true", help="Continue after a failed case.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    base_url = args.base_url.rstrip("/")
    out_dir = Path(args.out_dir).expanduser()
    output_dir = out_dir / "outputs"
    output_dir.mkdir(parents=True, exist_ok=True)

    sources = load_sources(args)
    health = http_json(f"{base_url}/ai-convert/health", timeout=30)
    if not health.get("ok"):
        raise SystemExit(f"Health check failed: {health}")

    voices_payload = http_json(f"{base_url}/ai-convert/voices", timeout=30)
    (out_dir / "voices.json").write_text(json.dumps(voices_payload, indent=2, ensure_ascii=False) + "\n")
    voices = selected_voices(voices_payload.get("voices", []), args.voices)
    if not voices:
        raise SystemExit("No voices selected.")

    results: list[CaseResult] = []
    case_count = 0
    for source in sources:
        source_dir = output_dir / slug(source.title)
        source_dir.mkdir(parents=True, exist_ok=True)
        for voice in voices:
            if args.max_cases and case_count >= args.max_cases:
                break
            case_count += 1

            voice_id = voice["voiceId"]
            target_gender = voice_gender(voice)
            target_genre = voice_genre(voice)
            output_path = source_dir / f"{slug(voice_id)}.mp3"
            print(f"[{case_count}] {source.title} -> {voice_id}", flush=True)

            status = "completed"
            error = ""
            job_id = ""
            pitch_shift = ""
            try:
                job_id, pitch_shift, _ = convert_case(base_url, source, voice, output_path, args)
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, RuntimeError, OSError) as exc:
                status = "failed"
                error = compact_error(exc)

            duration = probe_duration(output_path) if output_path.exists() else ""
            mean_volume, max_volume = probe_volume(output_path) if output_path.exists() else ("", "")
            size = str(output_path.stat().st_size) if output_path.exists() else ""

            results.append(
                CaseResult(
                    source_title=source.title,
                    source_path=str(source.path),
                    source_gender=source.gender,
                    source_genre=source.genre,
                    voice_id=voice_id,
                    voice_name=voice.get("name", ""),
                    target_gender=target_gender,
                    target_genre=target_genre,
                    combination=combination(source, target_gender, target_genre),
                    pitch_shift=pitch_shift,
                    status=status,
                    job_id=job_id,
                    duration_seconds=duration,
                    size_bytes=size,
                    mean_volume_db=mean_volume,
                    max_volume_db=max_volume,
                    output_path=str(output_path) if output_path.exists() else "",
                    error=error,
                )
            )
            print(f"    {status}{': ' + error if error else ''}", flush=True)
            write_results_csv(out_dir / "results.csv", results)
            if status != "completed" and not args.keep_going:
                print("Stopping after first failed case. Use --keep-going to continue.", flush=True)
                write_summary(out_dir / "summary.md", results, args)
                return 1

        if args.max_cases and case_count >= args.max_cases:
            break

    write_summary(out_dir / "summary.md", results, args)
    print(f"results: {out_dir / 'results.csv'}")
    print(f"summary: {out_dir / 'summary.md'}")
    return 0 if all(result.status == "completed" for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
