-- Fix de reingreso: un codigo debe seguir sirviendo hasta que el evento
-- termine (status closed/cancelled) o el organizador lo revoque -- NO vencer
-- por tiempo, y NO quedar bloqueado porque una sesion anonima anterior ya lo
-- habia reclamado. Es normal que el celular se cierre y el participante tenga
-- que reingresar con un usuario anonimo nuevo: en ese caso se re-vincula el
-- codigo al usuario actual mientras el evento siga abierto.

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

  -- El codigo deja de servir solo cuando el evento termino/cancelo,
  -- fue rechazado o el organizador lo revoco. NO vence por tiempo.
  if matched_event.status in ('closed', 'cancelled') then
    insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
    values (current_user_id, md5(normalized_code), false);
    return jsonb_build_object('error', 'El evento ya no acepta ingresos.');
  end if;

  if matched_participant.invite_status = 'rejected'
     or matched_participant.invite_revoked_at is not null then
    insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
    values (current_user_id, md5(normalized_code), false);
    return jsonb_build_object(
      'error',
      'Este codigo fue dado de baja. Pedile uno nuevo al coordinador.'
    );
  end if;

  -- Re-vinculacion: si el codigo ya estaba reclamado por otra sesion (por
  -- ejemplo la sesion anonima anterior del mismo participante que se cerro),
  -- se re-vincula al usuario actual mientras el evento siga abierto. El
  -- organizador puede revocar/regenerar el codigo si necesita cortar acceso.
  update public.event_participants
  set auth_user_id = current_user_id,
      invite_status = 'accepted',
      joined_at = coalesce(joined_at, now()),
      accepted_at = coalesce(accepted_at, now())
  where id = matched_participant.id
  returning * into matched_participant;

  insert into public.invite_attempts (auth_user_id, code_hash, succeeded)
  values (current_user_id, md5(normalized_code), true);

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

revoke all on function public.accept_event_invite(text) from anon, public;
grant execute on function public.accept_event_invite(text) to authenticated;

-- Los codigos ya emitidos con vencimiento a 7 dias: se alinean al fin del
-- evento (o se limpian) para que no confundan en la UI. El RPC ya no los usa.
update public.event_participants ep
set invite_expires_at = e.ends_at
from public.events e
where e.id = ep.event_id
  and ep.invite_expires_at is not null;
