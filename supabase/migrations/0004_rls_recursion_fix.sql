create or replace function public.can_listen_to_channel(target_channel_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_channels ec
    join public.channel_members cm on cm.channel_id = ec.id
    join public.event_participants ep on ep.id = cm.participant_id
    where ec.id = target_channel_id
      and ep.auth_user_id = auth.uid()
      and ep.invite_status = 'accepted'
      and cm.can_listen = true
  );
$$;

create or replace function public.can_talk_in_channel(target_channel_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_channels ec
    join public.channel_members cm on cm.channel_id = ec.id
    join public.event_participants ep on ep.id = cm.participant_id
    where ec.id = target_channel_id
      and ep.auth_user_id = auth.uid()
      and ep.invite_status = 'accepted'
      and cm.can_talk = true
  );
$$;

create or replace function public.can_view_channel_history(target_channel_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_channels ec
    join public.channel_members cm on cm.channel_id = ec.id
    join public.event_participants ep on ep.id = cm.participant_id
    where ec.id = target_channel_id
      and ep.auth_user_id = auth.uid()
      and ep.invite_status = 'accepted'
      and cm.can_view_history = true
  );
$$;

create or replace function public.can_manage_channel(target_channel_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_channels ec
    where ec.id = target_channel_id
      and public.is_event_admin(ec.event_id)
  );
$$;

grant execute on function public.can_listen_to_channel(uuid) to authenticated;
grant execute on function public.can_talk_in_channel(uuid) to authenticated;
grant execute on function public.can_view_channel_history(uuid) to authenticated;
grant execute on function public.can_manage_channel(uuid) to authenticated;

drop policy if exists "participants_read_event_channels"
  on public.event_channels;
create policy "participants_read_event_channels"
  on public.event_channels for select
  using (
    public.is_event_admin(event_id)
    or public.can_listen_to_channel(id)
  );

drop policy if exists "participants_read_channel_memberships"
  on public.channel_members;
create policy "participants_read_channel_memberships"
  on public.channel_members for select
  using (
    participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
    )
    or public.can_manage_channel(channel_id)
  );

drop policy if exists "admins_manage_channel_memberships"
  on public.channel_members;
create policy "admins_manage_channel_memberships"
  on public.channel_members for all
  using (public.can_manage_channel(channel_id))
  with check (public.can_manage_channel(channel_id));

drop policy if exists "participants_read_voice_messages"
  on public.voice_messages;
create policy "participants_read_voice_messages"
  on public.voice_messages for select
  using (
    public.is_event_participant(event_id)
    and public.can_view_channel_history(channel_id)
  );

drop policy if exists "participants_insert_voice_messages"
  on public.voice_messages;
create policy "participants_insert_voice_messages"
  on public.voice_messages for insert
  with check (
    public.is_event_participant(event_id)
    and participant_id in (
      select ep.id
      from public.event_participants ep
      where ep.auth_user_id = auth.uid()
    )
    and public.can_talk_in_channel(channel_id)
    and public.is_event_operational(event_id)
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

drop policy if exists "participants_read_event_audio"
  on storage.objects;
create policy "participants_read_event_audio"
  on storage.objects for select
  using (
    bucket_id = 'event-audio'
    and public.is_event_participant(((storage.foldername(name))[1])::uuid)
    and public.can_view_channel_history(((storage.foldername(name))[2])::uuid)
  );

drop policy if exists "participants_upload_event_audio"
  on storage.objects;
create policy "participants_upload_event_audio"
  on storage.objects for insert
  with check (
    bucket_id = 'event-audio'
    and owner = auth.uid()
    and public.is_event_participant(((storage.foldername(name))[1])::uuid)
    and public.can_talk_in_channel(((storage.foldername(name))[2])::uuid)
  );
