#!/usr/bin/env bash
set -euo pipefail

DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
PSQL_BIN="${PSQL_BIN:-psql}"

if ! command -v "$PSQL_BIN" >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/opt/libpq/bin/psql" ]; then
    PSQL_BIN="/opt/homebrew/opt/libpq/bin/psql"
  elif [ -x "/usr/local/opt/libpq/bin/psql" ]; then
    PSQL_BIN="/usr/local/opt/libpq/bin/psql"
  fi
fi

if ! command -v "$PSQL_BIN" >/dev/null 2>&1; then
  echo "psql no esta instalado o no esta en PATH." >&2
  exit 1
fi

"$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
update public.events
set
  status = 'active',
  starts_at = now() - interval '1 hour',
  ends_at = now() + interval '8 hours',
  updated_at = now()
where id = '10000000-0000-0000-0000-000000000001';

update public.event_participants
set
  auth_user_id = null,
  invite_status = 'pending',
  joined_at = null,
  accepted_at = null,
  invite_revoked_at = null,
  invite_expires_at = now() + interval '7 days'
where invite_code in ('SATI26', 'MARCOS26', 'ANA26', 'JULIA26');

insert into public.channel_members (
  channel_id,
  participant_id,
  can_listen,
  can_talk,
  can_view_history
)
values (
  '20000000-0000-0000-0000-000000000004',
  '30000000-0000-0000-0000-000000000005',
  true,
  false,
  true
)
on conflict (channel_id, participant_id) do update
set
  can_listen = excluded.can_listen,
  can_talk = excluded.can_talk,
  can_view_history = excluded.can_view_history;

select display_name, invite_code, invite_status, auth_user_id
from public.event_participants
where invite_code in ('SATI26', 'MARCOS26', 'ANA26', 'JULIA26')
order by invite_code;
SQL
