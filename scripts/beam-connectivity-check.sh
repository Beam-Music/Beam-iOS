#!/usr/bin/env bash
set -euo pipefail

GPU_BASE_URL="${GPU_BASE_URL:-http://127.0.0.1:8081}"
NEST_BASE_URL="${NEST_BASE_URL:-http://127.0.0.1:8080}"
AUDIO_FILE="${1:-}"

if [[ -z "$AUDIO_FILE" ]]; then
  echo "usage: GPU_BASE_URL=http://127.0.0.1:8081 NEST_BASE_URL=http://127.0.0.1:8080 $0 /path/to/input.mp3"
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "missing file: $AUDIO_FILE"
  exit 1
fi

echo "=== 1) GPU server direct smoke ==="
BASE_URL="$GPU_BASE_URL" ../beam-svc-server/scripts/smoke_test.sh "$AUDIO_FILE"

echo "=== 2) Nest gateway smoke ==="
BASE_URL="$NEST_BASE_URL" RETURN_JOB=true ../beam-server-nest/scripts/smoke_test.sh "$AUDIO_FILE"

echo "=== done ==="
