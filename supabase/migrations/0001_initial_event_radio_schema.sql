create extension if not exists pgcrypto;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'closed', 'cancelled')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists idx_events_status on public.events(status);
create index if not exists idx_events_created_by on public.events(created_by);

create table if not exists public.event_channels (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  name text not null,
  code text not null,
  description text,
  priority integer not null default 0 check (priority between 0 and 100),
  is_emergency boolean not null default false,
  livekit_room_name text not null unique,
  created_at timestamptz not null default now(),
  unique (event_id, code)
);

create index if not exists idx_channels_event on public.event_channels(event_id);

create table if not exists public.event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  display_name text not null,
  phone text,
  role text not null default 'participant'
    check (role in ('admin', 'coordinator', 'participant', 'viewer')),
  invite_code text unique not null,
  invite_status text not null default 'pending'
    check (invite_status in ('pending', 'accepted', 'rejected')),
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_participants_event
  on public.event_participants(event_id);
create index if not exists idx_participants_auth_user
  on public.event_participants(auth_user_id);
create index if not exists idx_participants_invite_code
  on public.event_participants(invite_code);

create table if not exists public.channel_members (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.event_channels(id) on delete cascade,
  participant_id uuid not null references public.event_participants(id) on delete cascade,
  can_listen boolean not null default true,
  can_talk boolean not null default true,
  can_view_history boolean not null default true,
  created_at timestamptz not null default now(),
  unique (channel_id, participant_id)
);

create index if not exists idx_channel_members_channel
  on public.channel_members(channel_id);
create index if not exists idx_channel_members_participant
  on public.channel_members(participant_id);

create table if not exists public.voice_messages (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  channel_id uuid not null references public.event_channels(id) on delete cascade,
  participant_id uuid not null references public.event_participants(id),
  storage_path text,
  audio_url text,
  duration_seconds numeric check (
    duration_seconds is null or duration_seconds >= 0
  ),
  transcription text,
  transcription_text text,
  transcription_status text not null default 'pending'
    check (
      transcription_status in (
        'pending',
        'queued',
        'processing',
        'completed',
        'failed',
        'skipped'
      )
    ),
  transcription_provider text,
  transcription_job_id text,
  is_priority boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_voice_messages_channel
  on public.voice_messages(channel_id, created_at desc);
create index if not exists idx_voice_messages_participant
  on public.voice_messages(participant_id);
create index if not exists idx_voice_messages_transcription_status
  on public.voice_messages(transcription_status, created_at);
create unique index if not exists idx_voice_messages_storage_path
  on public.voice_messages(storage_path)
  where storage_path is not null;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-audio',
  'event-audio',
  false,
  52428800,
  array['audio/aac', 'audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/webm']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.event_logs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  participant_id uuid references public.event_participants(id) on delete set null,
  channel_id uuid references public.event_channels(id) on delete set null,
  type text not null,
  title text not null,
  detail text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_event_logs_event
  on public.event_logs(event_id);
create index if not exists idx_event_logs_created_at
  on public.event_logs(created_at desc);

alter table public.events enable row level security;
alter table public.event_channels enable row level security;
alter table public.event_participants enable row level security;
alter table public.channel_members enable row level security;
alter table public.voice_messages enable row level security;
alter table public.event_logs enable row level security;

create or replace function public.is_event_participant(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_participants ep
    where ep.event_id = target_event_id
      and ep.auth_user_id = auth.uid()
      and ep.invite_status = 'accepted'
  );
$$;

create or replace function public.is_event_admin(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_participants ep
    where ep.event_id = target_event_id
      and ep.auth_user_id = auth.uid()
      and ep.invite_status = 'accepted'
      and ep.role in ('admin', 'coordinator')
  );
$$;

create policy "participants_read_joined_events"
  on public.events for select
  using (public.is_event_participant(id) or created_by = auth.uid());

create policy "admins_insert_events"
  on public.events for insert
  with check (created_by = auth.uid());

create policy "admins_update_events"
  on public.events for update
  using (public.is_event_admin(id) or created_by = auth.uid())
  with check (public.is_event_admin(id) or created_by = auth.uid());

create policy "participants_read_event_channels"
  on public.event_channels for select
  using (public.is_event_participant(event_id));

create policy "admins_manage_event_channels"
  on public.event_channels for all
  using (public.is_event_admin(event_id))
  with check (public.is_event_admin(event_id));

create policy "users_read_own_participant_rows"
  on public.event_participants for select
  using (
    auth_user_id = auth.uid()
    or public.is_event_admin(event_id)
  );

create policy "admins_manage_participants"
  on public.event_participants for all
  using (public.is_event_admin(event_id))
  with check (public.is_event_admin(event_id));

create policy "participants_read_channel_memberships"
  on public.channel_members for select
  using (
    participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
    )
    or exists (
      select 1
      from public.event_channels ec
      where ec.id = channel_id
        and public.is_event_admin(ec.event_id)
    )
  );

create policy "admins_manage_channel_memberships"
  on public.channel_members for all
  using (
    exists (
      select 1
      from public.event_channels ec
      where ec.id = channel_id
        and public.is_event_admin(ec.event_id)
    )
  )
  with check (
    exists (
      select 1
      from public.event_channels ec
      where ec.id = channel_id
        and public.is_event_admin(ec.event_id)
    )
  );

create policy "participants_read_voice_messages"
  on public.voice_messages for select
  using (
    public.is_event_participant(event_id)
    and channel_id in (
      select cm.channel_id
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and cm.can_view_history = true
    )
  );

create policy "participants_insert_voice_messages"
  on public.voice_messages for insert
  with check (
    public.is_event_participant(event_id)
    and participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
    )
    and channel_id in (
      select cm.channel_id
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and cm.can_talk = true
    )
    and (
      (
        transcription_status = 'pending'
        and audio_url is null
        and transcription is null
        and transcription_text is null
        and transcription_provider is null
        and transcription_job_id is null
        and (
          storage_path is null
          or storage_path like event_id::text || '/' || channel_id::text || '/%'
        )
      )
      or (
        is_priority = true
        and duration_seconds = 0
        and storage_path is null
        and audio_url is null
        and transcription_status = 'completed'
        and coalesce(transcription_text, transcription) is not null
        and transcription_provider is null
        and transcription_job_id is null
        and exists (
          select 1
          from public.event_channels ec
          where ec.id = channel_id
            and ec.event_id = event_id
            and ec.is_emergency = true
        )
      )
    )
  );

create policy "participants_read_event_audio"
  on storage.objects for select
  using (
    bucket_id = 'event-audio'
    and public.is_event_participant(((storage.foldername(name))[1])::uuid)
    and exists (
      select 1
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and cm.channel_id = ((storage.foldername(name))[2])::uuid
        and cm.can_view_history = true
    )
  );

create policy "participants_upload_event_audio"
  on storage.objects for insert
  with check (
    bucket_id = 'event-audio'
    and owner = auth.uid()
    and public.is_event_participant(((storage.foldername(name))[1])::uuid)
    and exists (
      select 1
      from public.channel_members cm
      join public.event_participants ep on ep.id = cm.participant_id
      where ep.auth_user_id = auth.uid()
        and cm.channel_id = ((storage.foldername(name))[2])::uuid
        and cm.can_talk = true
    )
  );

create policy "participants_read_event_logs"
  on public.event_logs for select
  using (public.is_event_participant(event_id));

create policy "admins_insert_event_logs"
  on public.event_logs for insert
  with check (public.is_event_admin(event_id));

-- Hito 1 usa datos mock por defecto. En Supabase real, no exponer busquedas
-- directas por invite_code desde el cliente; usar la RPC autenticada
-- accept_event_invite o una Edge Function equivalente con controles de abuso.
