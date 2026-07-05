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
        transcription_status = 'completed'
        and audio_url is null
        and transcription is null
        and transcription_text is not null
        and length(trim(transcription_text)) between 1 and 4000
        and transcription_provider = 'browser_speech'
        and transcription_job_id is null
        and duration_seconds is not null
        and duration_seconds > 0
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
