#!/usr/bin/env python3
"""Local Whisper transcription service for Event Radio development.

POST /transcribe with multipart/form-data field "file" containing a WAV file.
Returns: {"text": "..."}.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class TranscriptionServer(BaseHTTPRequestHandler):
    server_version = "EventRadioWhisper/0.1"

    def do_GET(self) -> None:
        if self.path != "/transcribe":
            self._json({"error": "Not found"}, status=404)
            return
        self._json(
            {
                "status": "ok",
                "service": "event-radio-whisper-local",
                "method": "POST multipart/form-data file=@audio.wav",
            }
        )

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_POST(self) -> None:
        if self.path != "/transcribe":
            self._json({"error": "Not found"}, status=404)
            return

        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            self._json({"error": "Expected multipart/form-data"}, status=400)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            audio_bytes = _multipart_file_bytes(body, content_type, "file")
            if audio_bytes is None:
                self._json({"error": "Missing multipart field: file"}, status=400)
                return

            with tempfile.TemporaryDirectory(prefix="event-radio-whisper-") as tmp:
                tmp_dir = Path(tmp)
                audio_path = tmp_dir / "audio.wav"
                output_base = tmp_dir / "transcript"
                with audio_path.open("wb") as output:
                    output.write(audio_bytes)

                result = self._run_whisper(audio_path, output_base)
                if result.returncode != 0:
                    self._json(
                        {
                            "error": "whisper-cli failed",
                            "detail": result.stderr[-2000:],
                        },
                        status=500,
                    )
                    return

                transcript_path = output_base.with_suffix(".txt")
                text = transcript_path.read_text(encoding="utf-8").strip()
                self._json({"text": text})
        except Exception as error:  # noqa: BLE001 - service boundary
            self._json({"error": str(error)}, status=500)

    def _run_whisper(self, audio_path: Path, output_base: Path) -> subprocess.CompletedProcess[str]:
        command = [
            self.server.whisper_bin,  # type: ignore[attr-defined]
            "--model",
            self.server.model_path,  # type: ignore[attr-defined]
            "--file",
            str(audio_path),
            "--language",
            self.server.language,  # type: ignore[attr-defined]
            "--output-txt",
            "--output-file",
            str(output_base),
            "--no-timestamps",
            "--no-prints",
        ]
        return subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=self.server.timeout_seconds,  # type: ignore[attr-defined]
        )

    def _json(self, payload: dict[str, object], status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "content-type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

    def log_message(self, format: str, *args: object) -> None:
        print("%s - %s" % (self.address_string(), format % args))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument(
        "--model",
        default=os.environ.get(
            "WHISPER_MODEL",
            str(Path.cwd() / ".local/whisper-models/ggml-base.bin"),
        ),
    )
    parser.add_argument(
        "--whisper-bin",
        default=os.environ.get("WHISPER_BIN", "whisper-cli"),
    )
    parser.add_argument("--language", default=os.environ.get("WHISPER_LANGUAGE", "es"))
    parser.add_argument("--timeout-seconds", type=int, default=120)
    return parser.parse_args()


def _multipart_file_bytes(
    body: bytes,
    content_type: str,
    field_name: str,
) -> bytes | None:
    boundary_marker = "boundary="
    if boundary_marker not in content_type:
        return None

    boundary = content_type.split(boundary_marker, 1)[1].split(";", 1)[0].strip()
    boundary = boundary.strip('"')
    delimiter = ("--" + boundary).encode("utf-8")

    for raw_part in body.split(delimiter):
        part = raw_part.strip(b"\r\n")
        if not part or part == b"--":
            continue
        headers_raw, separator, content = part.partition(b"\r\n\r\n")
        if not separator:
            continue
        headers = headers_raw.decode("utf-8", errors="ignore").lower()
        if f'name="{field_name}"' not in headers:
            continue
        if content.endswith(b"\r\n"):
            content = content[:-2]
        if content.endswith(b"--"):
            content = content[:-2]
        return content

    return None


def main() -> None:
    args = parse_args()
    model_path = Path(args.model).expanduser().resolve()
    if not model_path.exists():
        raise SystemExit(f"Model not found: {model_path}")

    whisper_bin = shutil.which(args.whisper_bin) or args.whisper_bin
    server = ThreadingHTTPServer((args.host, args.port), TranscriptionServer)
    server.model_path = str(model_path)  # type: ignore[attr-defined]
    server.whisper_bin = whisper_bin  # type: ignore[attr-defined]
    server.language = args.language  # type: ignore[attr-defined]
    server.timeout_seconds = args.timeout_seconds  # type: ignore[attr-defined]

    print(f"Serving local Whisper on http://{args.host}:{args.port}/transcribe")
    print(f"Model: {model_path}")
    print(f"Binary: {whisper_bin}")
    server.serve_forever()


if __name__ == "__main__":
    main()
