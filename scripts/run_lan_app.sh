#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
}

LAN_IP_VALUE="$(detect_lan_ip)"
if [[ -z "$LAN_IP_VALUE" ]]; then
  echo "No pude detectar la IP LAN. Ejecuta con LAN_IP=tu.ip.local." >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Falta .env. Crea uno desde .env.example antes de correr la app." >&2
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

cat <<EOF
Corriendo app nativa contra Supabase LAN:
  ${LAN_SUPABASE_URL}

Si no elegis dispositivo, Flutter va a pedir uno.
Ejemplos:
  scripts/run_lan_app.sh -d <device-id>
  LAN_IP=${LAN_IP_VALUE} scripts/run_lan_app.sh -d <device-id>

EOF

flutter run "$@"
