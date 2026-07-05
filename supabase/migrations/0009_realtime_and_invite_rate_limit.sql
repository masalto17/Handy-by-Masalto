-- Fase 3: sincronizacion realtime + rate limit de invitaciones.

-- 1. Registro de intentos de canje de invitacion (anti fuerza bruta).
--    Solo la funcion security definer escribe/lee; sin policies de cliente.
create table if not exists public.invite_attempts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null,
  code_hash text not null,
  succeeded boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_invite_attempts_user_time
  on public.invite_attempts(auth_user_id, created_at desc);

alter table public.invite_attempts enable row level security;

-- 2. accept_event_invite con rate limit y auditoria.
--    Los fallos de validacion ahora RETORNAN jsonb con 'error' en lugar de
--    raise exception, para que el registro del intento quede commiteado.
create or replace function public.accept_event_invite(invite_code_input text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_code text;
  matched_participant public.event_participants%rowtype;
  matched_event public.events%rowtype;
  current_user_id uuid;
  recent_failures integer;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Inicia sesion para vincular esta invitacion.';
  end if;

  normalized_code := regexp_replace(
    upper(coalesce(invite_code_input, '')),
    '[^A-Z0-9]+',
    '',
    'g'
  );
  if normalized_code = '' then
    return jsonb_build_object('error', 'El codigo esta vacio.');
  end if;

  -- Rate limit: maximo 10 intentos fallidos por usuario por hora.
  select count(*)
  into recent_failures
  from public.invite_attempts
  where auth_user_id = current_user_id
    and succeeded = false
    and created_at > now() - interval '1 hour';

  if recent_failures >= 10 then
    return jsonb_build_object(
      'error',
      'Demasiados intentos fallidos. Espera un rato y proba de nuevo.'
    );
  end if;

  select *
  into matched_participant
  from public.event_participants
  where invite_code = normalized_code
  for update;

  if not found then
    insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
    values (current_user_id, md5(normalized_code), false);
    return jsonb_build_object(
      'error',
      'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.'
    );
  end if;

  select *
  into matched_event
  from public.events
  where id = matched_participant.event_id;

  if matched_event.status in ('closed', 'cancelled') then
    insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
    values (current_user_id, md5(normalized_code), false);
    return jsonb_build_object('error', 'El evento ya no acepta ingresos.');
  end if;

  if matched_participant.invite_status = 'rejected'
     or matched_participant.invite_revoked_at is not null
     or (
       matched_participant.invite_expires_at is not null
       and matched_participant.invite_expires_at < now()
     )
     or (
       matched_participant.auth_user_id is not null
       and matched_participant.auth_user_id <> current_user_id
     ) then
    insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
    values (current_user_id, md5(normalized_code), false);
    return jsonb_build_object(
      'error',
      'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.'
    );
  end if;

  update public.event_participants
  set auth_user_id = current_user_id,
      invite_status = 'accepted',
      joined_at = coalesce(joined_at, now()),
      accepted_at = coalesce(accepted_at, now())
  where id = matched_participant.id
  returning * into matched_participant;

  insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
  values (current_user_id, md5(normalized_code), true);

  -- Limpieza oportunista de intentos viejos.
  delete from public.invite_attempts where created_at < now() - interval '7 days';

  insert into public.event_logs (
    event_id,
    participant_id,
    type,
    title,
    detail
  )
  values (
    matched_participant.event_id,
    matched_participant.id,
    'participant_joined',
    matched_participant.display_name || ' ingreso al evento',
    'Ingreso validado con invitacion.'
  );

  return jsonb_build_object('participant_id', matched_participant.id);
end;
$$;

revoke all on function public.accept_event_invite(text) from public;
grant execute on function public.accept_event_invite(text) to authenticated;

-- 3. Habilitar realtime (postgres_changes) para sincronizacion en vivo.
--    RLS sigue aplicando: cada cliente solo recibe filas que puede leer.
do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'events',
    'event_channels',
    'event_participants',
    'channel_members',
    'voice_messages'
  ]
  loop
    begin
      execute format(
        'alter publication supabase_realtime add table public.%I',
        target_table
      );
    exception
      when duplicate_object then null;
      when undefined_object then null;
    end;
  end loop;
end;
$$;
