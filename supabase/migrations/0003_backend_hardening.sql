alter table public.event_participants
  add column if not exists invite_expires_at timestamptz,
  add column if not exists invite_revoked_at timestamptz,
  add column if not exists accepted_at timestamptz;

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.events to authenticated;
grant select, insert, update, delete on table public.event_channels to authenticated;
grant select, insert, update, delete on table public.event_participants to authenticated;
grant select, insert, update, delete on table public.channel_members to authenticated;
grant select, insert on table public.voice_messages to authenticated;
grant select, insert on table public.event_logs to authenticated;

create index if not exists idx_participants_active_invites
  on public.event_participants(invite_code)
  where invite_status = 'pending' and invite_revoked_at is null;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_events_updated_at on public.events;
create trigger touch_events_updated_at
  before update on public.events
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_event_participants_updated_at
  on public.event_participants;
create trigger touch_event_participants_updated_at
  before update on public.event_participants
  for each row execute function public.touch_updated_at();

create or replace function public.channel_member_matches_event()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  channel_event_id uuid;
  participant_event_id uuid;
begin
  select event_id into channel_event_id
  from public.event_channels
  where id = new.channel_id;

  select event_id into participant_event_id
  from public.event_participants
  where id = new.participant_id;

  if channel_event_id is null or participant_event_id is null then
    raise exception 'Canal o participante inexistente.';
  end if;

  if channel_event_id <> participant_event_id then
    raise exception 'El canal y el participante pertenecen a eventos distintos.';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_channel_member_event
  on public.channel_members;
create trigger enforce_channel_member_event
  before insert or update on public.channel_members
  for each row execute function public.channel_member_matches_event();

create or replace function public.is_event_operational(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events e
    where e.id = target_event_id
      and e.status = 'active'
      and now() >= e.starts_at
      and now() < e.ends_at
  );
$$;

drop policy if exists "participants_read_event_channels"
  on public.event_channels;
create policy "participants_read_event_channels"
  on public.event_channels for select
  using (
    public.is_event_admin(event_id)
    or id in (
      select cm.channel_id
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and ep.invite_status = 'accepted'
        and cm.can_listen = true
    )
  );

create or replace function public.create_event_with_admin(
  event_name text,
  event_description text,
  starts_at_input timestamptz,
  ends_at_input timestamptz,
  admin_display_name text,
  admin_phone text default null,
  admin_invite_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  new_event public.events%rowtype;
  new_channel public.event_channels%rowtype;
  new_participant public.event_participants%rowtype;
  normalized_invite text;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Inicia sesion para crear un evento.';
  end if;

  if trim(coalesce(event_name, '')) = '' then
    raise exception 'El nombre del evento es obligatorio.';
  end if;

  if ends_at_input <= starts_at_input then
    raise exception 'La fecha de fin debe ser posterior al inicio.';
  end if;

  normalized_invite := regexp_replace(
    upper(coalesce(admin_invite_code, encode(gen_random_bytes(9), 'hex'))),
    '[^A-Z0-9]+',
    '',
    'g'
  );

  insert into public.events (
    name,
    description,
    starts_at,
    ends_at,
    status,
    created_by
  )
  values (
    trim(event_name),
    nullif(trim(coalesce(event_description, '')), ''),
    starts_at_input,
    ends_at_input,
    'active',
    current_user_id
  )
  returning * into new_event;

  insert into public.event_participants (
    event_id,
    auth_user_id,
    display_name,
    phone,
    role,
    invite_code,
    invite_status,
    joined_at,
    accepted_at
  )
  values (
    new_event.id,
    current_user_id,
    trim(coalesce(admin_display_name, 'Coordinador')),
    nullif(trim(coalesce(admin_phone, '')), ''),
    'coordinator',
    normalized_invite,
    'accepted',
    now(),
    now()
  )
  returning * into new_participant;

  insert into public.event_channels (
    event_id,
    name,
    code,
    description,
    priority,
    is_emergency,
    livekit_room_name
  )
  values (
    new_event.id,
    'Produccion',
    'produccion',
    'Coordinacion general del evento.',
    70,
    false,
    'event_' || new_event.id::text || '_produccion'
  )
  returning * into new_channel;

  insert into public.channel_members (
    channel_id,
    participant_id,
    can_listen,
    can_talk,
    can_view_history
  )
  values (
    new_channel.id,
    new_participant.id,
    true,
    true,
    true
  );

  insert into public.event_logs (
    event_id,
    participant_id,
    type,
    title,
    detail
  )
  values (
    new_event.id,
    new_participant.id,
    'event_created',
    'Evento creado',
    new_event.name
  );

  return jsonb_build_object(
    'event_id', new_event.id,
    'participant_id', new_participant.id,
    'channel_id', new_channel.id
  );
end;
$$;

revoke all on function public.create_event_with_admin(
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) from public;
grant execute on function public.create_event_with_admin(
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) to authenticated;

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
    raise exception 'El codigo esta vacio.';
  end if;

  select *
  into matched_participant
  from public.event_participants
  where invite_code = normalized_code
  for update;

  if not found then
    raise exception 'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.';
  end if;

  select *
  into matched_event
  from public.events
  where id = matched_participant.event_id;

  if matched_event.status in ('closed', 'cancelled') then
    raise exception 'El evento ya no acepta ingresos.';
  end if;

  if matched_participant.invite_status = 'rejected'
     or matched_participant.invite_revoked_at is not null
     or (
       matched_participant.invite_expires_at is not null
       and matched_participant.invite_expires_at < now()
     ) then
    raise exception 'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.';
  end if;

  if matched_participant.auth_user_id is not null
     and matched_participant.auth_user_id <> current_user_id then
    raise exception 'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.';
  end if;

  update public.event_participants
  set auth_user_id = current_user_id,
      invite_status = 'accepted',
      joined_at = coalesce(joined_at, now()),
      accepted_at = coalesce(accepted_at, now())
  where id = matched_participant.id
  returning * into matched_participant;

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

drop policy if exists "participants_insert_voice_messages"
  on public.voice_messages;
create policy "participants_insert_voice_messages"
  on public.voice_messages for insert
  with check (
    public.is_event_operational(event_id)
    and participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
        and ep.invite_status = 'accepted'
    )
    and channel_id in (
      select cm.channel_id
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and ep.invite_status = 'accepted'
        and cm.can_talk = true
    )
    and audio_url is null
    and transcription is null
    and transcription_text is null
    and transcription_provider is null
    and transcription_job_id is null
  );

drop policy if exists "admins_insert_event_logs"
  on public.event_logs;
create policy "admins_insert_event_logs"
  on public.event_logs for insert
  with check (public.is_event_admin(event_id));

drop policy if exists "participants_insert_operational_event_logs"
  on public.event_logs;
create policy "participants_insert_operational_event_logs"
  on public.event_logs for insert
  with check (
    public.is_event_participant(event_id)
    and type in ('message_sent', 'broadcast_message', 'emergency_message')
    and participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
        and ep.invite_status = 'accepted'
    )
    and detail not ilike '%codigo%'
    and detail not ilike '%code%'
  );
