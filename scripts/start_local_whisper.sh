#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_PATH="${WHISPER_MODEL:-$ROOT_DIR/.local/whisper-models/ggml-base.bin}"

python3 "$ROOT_DIR/local_services/whisper_transcriber/server.py" \
  --model "$MODEL_PATH" \
  --host "${WHISPER_HOST:-127.0.0.1}" \
  --port "${WHISPER_PORT:-8787}" \
  --language "${WHISPER_LANGUAGE:-es}"
