#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8081}"
SUPABASE_PORT="${SUPABASE_PORT:-54321}"

detect_lan_ip() {
  if [[ -n "${LAN_IP:-}" ]]; then
    printf '%s\n' "$LAN_IP"
    return
  fi

  for iface in en0 en1; do
    local ip
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      printf '%s\n' "$ip"
      return
    fi
  done

  route -n get default 2>/dev/null \
    | awk '/interface:/{print $2}' \
    | while read -r iface; do
        ipconfig getifaddr "$iface" 2>/dev/null || true
      done \
    | awk 'NF {print; exit}'
}

LAN_IP_VALUE="$(detect_lan_ip)"
if [[ -z "$LAN_IP_VALUE" ]]; then
  echo "No pude detectar la IP LAN. Ejecuta con LAN_IP=tu.ip.local." >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Falta .env. Crea uno desde .env.example antes de iniciar LAN." >&2
  exit 1
fi

ENV_BACKUP="$(mktemp)"
cp .env "$ENV_BACKUP"
restore_env() {
  cp "$ENV_BACKUP" .env
  rm -f "$ENV_BACKUP"
}
trap restore_env EXIT

LAN_SUPABASE_URL="http://${LAN_IP_VALUE}:${SUPABASE_PORT}"

python3 - "$LAN_SUPABASE_URL" <<'PY'
from pathlib import Path
import sys

env_path = Path(".env")
target_url = sys.argv[1]
lines = env_path.read_text().splitlines()
updated = False
for index, line in enumerate(lines):
    if line.startswith("SUPABASE_URL="):
        lines[index] = f"SUPABASE_URL={target_url}"
        updated = True
        break
if not updated:
    lines.insert(0, f"SUPABASE_URL={target_url}")
env_path.write_text("\n".join(lines) + "\n")
PY

echo "Construyendo web para LAN con Supabase: ${LAN_SUPABASE_URL}"
flutter build web
restore_env
trap - EXIT

if command -v lsof >/dev/null 2>&1; then
  EXISTING_PIDS="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$EXISTING_PIDS" ]]; then
    echo "Cerrando servidor anterior en puerto ${PORT}: ${EXISTING_PIDS}"
    kill $EXISTING_PIDS 2>/dev/null || true
  fi
fi

cat <<EOF

Preview LAN lista:
  Esta Mac: http://127.0.0.1:${PORT}/
  Otros dispositivos en la misma Wi-Fi: http://${LAN_IP_VALUE}:${PORT}/

Requisitos para telefonos/computadoras externas:
  - Misma red Wi-Fi.
  - Supabase local activo en ${LAN_SUPABASE_URL}.
  - Edge Functions activas en ${LAN_SUPABASE_URL}/functions/v1.
  - Whisper local activo si queres transcripcion.
  - Permitir conexiones entrantes si macOS muestra un aviso de firewall.

Mantene esta terminal abierta mientras prueban.

EOF

python3 -m http.server "$PORT" --bind 0.0.0.0 --directory build/web
