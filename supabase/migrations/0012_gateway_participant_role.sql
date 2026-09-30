-- Rol para el puente con handies UHF.
--
-- El puente entra al evento como un participante mas (ver gateway/README.md).
-- Necesita un rol propio por dos razones:
--
--   1. La app tiene que poder distinguirlo de un celular para mostrar el
--      estado del enlace de radio. El rol viaja firmado en el token de
--      LiveKit, asi que un participante comun no puede hacerse pasar por
--      puente cambiando algo del lado del cliente.
--   2. Solo a ese rol se le da permiso de publicar atributos en la sala
--      (canUpdateOwnMetadata en la edge function livekit-token), que es como
--      el puente informa si esta transmitiendo al aire.
--
-- El permiso de hablar sigue saliendo de channel_members.can_talk, igual que
-- para cualquier otro participante: este rol no lo otorga por si mismo.

-- La restriccion original se declaro en linea, sin nombre explicito, asi que
-- quedo con el nombre que le puso Postgres. Se la busca por su definicion en
-- vez de asumir ese nombre: si quedara viva, seguiria rechazando 'gateway'
-- aunque la nueva se agregue igual.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'event_participants'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%viewer%'
  loop
    execute format(
      'alter table public.event_participants drop constraint %I',
      constraint_name
    );
  end loop;
end;
$$;

alter table public.event_participants
  add constraint event_participants_role_check
  check (role in ('admin', 'coordinator', 'participant', 'viewer', 'gateway'));
