create or replace function public.livekit_token_context(target_channel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  context_row record;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Inicia sesion para pedir audio LiveKit.';
  end if;

  select
    e.id as event_id,
    e.status as event_status,
    e.starts_at,
    e.ends_at,
    ec.id as channel_id,
    ec.name as channel_name,
    ec.livekit_room_name,
    ep.id as participant_id,
    ep.display_name,
    ep.role,
    cm.can_listen,
    cm.can_talk
  into context_row
  from public.event_channels ec
  join public.events e on e.id = ec.event_id
  join public.channel_members cm on cm.channel_id = ec.id
  join public.event_participants ep on ep.id = cm.participant_id
  where ec.id = target_channel_id
    and ep.auth_user_id = current_user_id
    and ep.invite_status = 'accepted'
  limit 1;

  if not found then
    raise exception 'No tenes acceso a este canal.';
  end if;

  if context_row.event_status <> 'active'
     or now() < context_row.starts_at
     or now() >= context_row.ends_at then
    raise exception 'El evento no esta operativo.';
  end if;

  if context_row.can_listen is not true then
    raise exception 'No tenes permiso para escuchar este canal.';
  end if;

  return jsonb_build_object(
    'event_id', context_row.event_id,
    'channel_id', context_row.channel_id,
    'channel_name', context_row.channel_name,
    'room_name', context_row.livekit_room_name,
    'participant_id', context_row.participant_id,
    'participant_name', context_row.display_name,
    'participant_role', context_row.role,
    'can_publish_audio', context_row.can_talk is true
  );
end;
$$;

revoke all on function public.livekit_token_context(uuid) from public;
grant execute on function public.livekit_token_context(uuid) to authenticated;
