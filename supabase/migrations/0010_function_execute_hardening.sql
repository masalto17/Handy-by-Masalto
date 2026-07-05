-- Fase 5 (hardening): las funciones security definer no deben ser ejecutables
-- por el rol anon (sin sesion). La app usa auth anonima de Supabase, por lo que
-- todo acceso real ocurre como authenticated. Se revoca execute a anon/public y
-- se mantiene solo authenticated (necesario para evaluar las policies RLS y para
-- las RPC de negocio).

do $$
declare
  fn text;
  fns text[] := array[
    'public.is_event_participant(uuid)',
    'public.is_event_admin(uuid)',
    'public.is_event_operational(uuid)',
    'public.can_listen_to_channel(uuid)',
    'public.can_talk_in_channel(uuid)',
    'public.can_view_channel_history(uuid)',
    'public.can_manage_channel(uuid)',
    'public.accept_event_invite(text)',
    'public.livekit_token_context(uuid)',
    'public.create_event_with_admin(text, text, timestamptz, timestamptz, text, text, text)'
  ];
begin
  foreach fn in array fns
  loop
    execute format('revoke all on function %s from anon, public;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end;
$$;
