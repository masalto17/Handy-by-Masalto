-- Checks RLS mínimos para Event Radio.
-- Ejecutar después de migraciones + supabase/seed_mvp.sql.

\set ON_ERROR_STOP on

create schema if not exists test;

create or replace function test.assert_true(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition, false) then
    raise exception 'ASSERT TRUE failed: %', message;
  end if;
end;
$$;

create or replace function test.assert_false(condition boolean, message text)
returns void
language plpgsql
as $$
begin
  if coalesce(condition, false) then
    raise exception 'ASSERT FALSE failed: %', message;
  end if;
end;
$$;

create or replace function test.as_user(user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
end;
$$;

grant usage on schema test to authenticated;
grant execute on all functions in schema test to authenticated;

begin;

set local role authenticated;

select test.as_user('00000000-0000-0000-0000-000000000199');
select test.assert_false(
  exists (
    select 1
    from public.events
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  'usuario externo no debe leer evento'
);

select test.as_user('00000000-0000-0000-0000-000000000102');
select test.assert_true(
  exists (
    select 1
    from public.events
    where id = '10000000-0000-0000-0000-000000000001'
  ),
  'seguridad aceptado debe leer evento'
);
select test.assert_false(
  exists (
    select 1
    from public.event_channels
    where id = '20000000-0000-0000-0000-000000000001'
  ),
  'seguridad no debe ver canal produccion'
);
select test.assert_true(
  exists (
    select 1
    from public.event_channels
    where id = '20000000-0000-0000-0000-000000000002'
  ),
  'seguridad debe ver canal seguridad'
);

select test.as_user('00000000-0000-0000-0000-000000000104');
select test.assert_false(
  exists (
    select 1
    from public.event_participants
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  'viewer no debe leer otros participantes'
);

do $$
begin
  insert into public.voice_messages (
    event_id,
    channel_id,
    participant_id,
    duration_seconds,
    transcription_status
  )
  values (
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000004',
    2,
    'pending'
  );
  raise exception 'viewer no debe poder insertar PTT';
exception
  when insufficient_privilege or check_violation or with_check_option_violation then
    null;
end;
$$;

select test.as_user('00000000-0000-0000-0000-000000000102');
do $$
begin
  insert into public.voice_messages (
    event_id,
    channel_id,
    participant_id,
    duration_seconds,
    transcription_status
  )
  values (
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    2,
    'pending'
  );
  raise exception 'seguridad no debe hablar en produccion';
exception
  when insufficient_privilege or check_violation or with_check_option_violation then
    null;
end;
$$;

insert into public.voice_messages (
  event_id,
  channel_id,
  participant_id,
  duration_seconds,
  transcription_status
)
values (
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002',
  '30000000-0000-0000-0000-000000000002',
  2,
  'pending'
);

do $$
begin
  insert into public.voice_messages (
    event_id,
    channel_id,
    participant_id,
    duration_seconds,
    transcription_status,
    transcription_text
  )
  values (
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    2,
    'completed',
    'texto no permitido desde cliente'
  );
  raise exception 'cliente no debe escribir transcripcion';
exception
  when insufficient_privilege or check_violation or with_check_option_violation then
    null;
end;
$$;

select test.as_user('00000000-0000-0000-0000-000000000101');
select test.assert_true(
  exists (
    select 1
    from public.event_participants
    where id = '30000000-0000-0000-0000-000000000002'
  ),
  'admin debe leer participantes del evento'
);

do $$
begin
  insert into public.channel_members (
    channel_id,
    participant_id,
    can_listen,
    can_talk,
    can_view_history
  )
  values (
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000005',
    true,
    true,
    true
  )
  on conflict do nothing;
exception
  when others then
    raise exception 'admin debe poder asignar permisos validos: %', sqlerrm;
end;
$$;

reset role;

select test.assert_false(
  exists (
    select 1
    from public.event_logs
    where event_id = '10000000-0000-0000-0000-000000000001'
      and (
        coalesce(detail, '') ilike '%PILOTOADMIN123%'
        or coalesce(detail, '') ilike '%PILOTOSEGUR123%'
        or coalesce(detail, '') ilike '%PILOTOPRODU123%'
        or coalesce(detail, '') ilike '%PILOTOVIEW123%'
        or coalesce(detail, '') ilike '%PILOTOPEND123%'
        or coalesce(detail, '') ilike '%SATI26%'
        or coalesce(detail, '') ilike '%MARCOS26%'
        or coalesce(detail, '') ilike '%ANA26%'
        or coalesce(detail, '') ilike '%JULIA26%'
      )
  ),
  'logs no deben contener codigos de invitacion'
);

rollback;

select 'RLS checks OK' as result;
