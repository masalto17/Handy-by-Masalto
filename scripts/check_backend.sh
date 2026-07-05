#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
PSQL_BIN="${PSQL_BIN:-psql}"

cd "$ROOT_DIR"

if ! command -v "$PSQL_BIN" >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/opt/libpq/bin/psql" ]; then
    PSQL_BIN="/opt/homebrew/opt/libpq/bin/psql"
  elif [ -x "/usr/local/opt/libpq/bin/psql" ]; then
    PSQL_BIN="/usr/local/opt/libpq/bin/psql"
  fi
fi

if ! command -v "$PSQL_BIN" >/dev/null 2>&1; then
  echo "psql no esta instalado o no esta en PATH." >&2
  echo "Instalar en macOS: brew install libpq" >&2
  exit 1
fi

if [[ "$DB_URL" != *"127.0.0.1"* && "$DB_URL" != *"localhost"* ]]; then
  if [[ "${ALLOW_REMOTE_DB_SEED:-}" != "true" ]]; then
    echo "SUPABASE_DB_URL no apunta a localhost." >&2
    echo "Este script aplica migraciones y carga datos de prueba." >&2
    echo "Para una base remota de staging, ejecutar con ALLOW_REMOTE_DB_SEED=true." >&2
    exit 1
  fi
fi

MIGRATIONS_APPLIED="$("$PSQL_BIN" "$DB_URL" -tAc "
  select exists (
    select 1
    from information_schema.tables
    where table_schema = 'supabase_migrations'
      and table_name = 'schema_migrations'
  ) and exists (
    select 1 from supabase_migrations.schema_migrations
  );
" 2>/dev/null || echo "f")"

if [[ "$MIGRATIONS_APPLIED" == "t" ]]; then
  echo "==> Migraciones ya aplicadas; se omite reaplicacion"
else
  echo "==> Aplicando migraciones"
  for migration in supabase/migrations/*.sql; do
    echo "    $migration"
    "$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null
  done
fi

echo "==> Cargando seed MVP"
"$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/seed_mvp.sql >/dev/null

echo "==> Corriendo checks RLS"
"$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_checks.sql

echo "==> Corriendo tests Flutter"
flutter test

echo "Backend checks OK"
