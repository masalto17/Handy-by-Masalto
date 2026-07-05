create policy "event_creators_create_participants"
  on public.event_participants for insert
  with check (
    exists (
      select 1
      from public.events e
      where e.id = event_id
        and e.created_by = auth.uid()
    )
  );

create policy "event_creators_read_participants"
  on public.event_participants for select
  using (
    exists (
      select 1
      from public.events e
      where e.id = event_id
        and e.created_by = auth.uid()
    )
  );

create or replace function public.accept_event_invite(invite_code_input text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_code text;
  matched_participant public.event_participants%rowtype;
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

  if matched_participant.auth_user_id is not null
     and matched_participant.auth_user_id <> current_user_id then
    raise exception 'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.';
  end if;

  update public.event_participants
  set auth_user_id = current_user_id,
      invite_status = 'accepted',
      joined_at = coalesce(joined_at, now()),
      updated_at = now()
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
    'Ingreso validado con codigo de invitacion.'
  );

  return jsonb_build_object('participant_id', matched_participant.id);
end;
$$;

revoke all on function public.accept_event_invite(text) from public;
grant execute on function public.accept_event_invite(text) to authenticated;
