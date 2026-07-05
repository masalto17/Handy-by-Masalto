create extension if not exists pgcrypto with schema extensions;

alter function public.create_event_with_admin(
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  text
) set search_path = public, extensions;
