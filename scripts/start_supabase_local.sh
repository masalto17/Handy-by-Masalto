#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker no esta instalado o no esta en PATH." >&2
  echo "Supabase local requiere Docker Desktop corriendo." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker no esta corriendo." >&2
  echo "Abrir Docker Desktop y volver a ejecutar este script." >&2
  exit 1
fi

if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI no esta instalado." >&2
  echo "Instalar en macOS: brew install supabase/tap/supabase" >&2
  exit 1
fi

supabase start

echo "Supabase local iniciado."
echo "DB URL para checks:"
echo "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
