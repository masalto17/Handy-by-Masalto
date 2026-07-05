-- Seed reproducible para probar Event Radio en Supabase local/staging.
-- No usar estos codigos en produccion.

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@event-radio.test',
    crypt('event-radio-admin', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'seguridad@event-radio.test',
    crypt('event-radio-seguridad', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'produccion@event-radio.test',
    crypt('event-radio-produccion', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'viewer@event-radio.test',
    crypt('event-radio-viewer', gen_salt('bf')),
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000199',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'externo@event-radio.test',
    crypt('event-radio-externo', gen_salt('bf')),
    now(),
    now(),
    now()
  )
on conflict (id) do update
set
  email = excluded.email,
  updated_at = now();

update auth.users
set
  confirmation_token = '',
  recovery_token = '',
  email_change_token_new = '',
  email_change = '',
  email_change_token_current = '',
  phone_change = '',
  phone_change_token = '',
  reauthentication_token = '',
  raw_app_meta_data = coalesce(raw_app_meta_data, '{"provider":"email","providers":["email"]}'::jsonb),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb),
  is_super_admin = coalesce(is_super_admin, false),
  is_sso_user = false,
  is_anonymous = false,
  updated_at = now()
where id in (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000103',
  '00000000-0000-0000-0000-000000000104',
  '00000000-0000-0000-0000-000000000199'
);

insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000101',
    '{"sub":"00000000-0000-0000-0000-000000000101","email":"admin@event-radio.test","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000102',
    '{"sub":"00000000-0000-0000-0000-000000000102","email":"seguridad@event-radio.test","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000103',
    '{"sub":"00000000-0000-0000-0000-000000000103","email":"produccion@event-radio.test","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000104',
    '{"sub":"00000000-0000-0000-0000-000000000104","email":"viewer@event-radio.test","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000199',
    '00000000-0000-0000-0000-000000000199',
    '{"sub":"00000000-0000-0000-0000-000000000199","email":"externo@event-radio.test","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now(),
    now()
  )
on conflict (provider_id, provider) do update
set
  user_id = excluded.user_id,
  identity_data = excluded.identity_data,
  updated_at = now();

insert into public.events (
  id,
  name,
  description,
  starts_at,
  ends_at,
  status,
  created_by
)
values (
  '10000000-0000-0000-0000-000000000001',
  'Piloto Event Radio',
  'Evento realista para validar roles, canales y permisos.',
  now() - interval '1 hour',
  now() + interval '8 hours',
  'active',
  '00000000-0000-0000-0000-000000000101'
)
on conflict (id) do update
set
  name = excluded.name,
  description = excluded.description,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  status = excluded.status,
  created_by = excluded.created_by;

insert into public.event_channels (
  id,
  event_id,
  name,
  code,
  description,
  priority,
  is_emergency,
  livekit_room_name
)
values
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Produccion',
    'produccion',
    'Coordinacion general.',
    80,
    false,
    'event_piloto_produccion'
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Seguridad',
    'seguridad',
    'Equipo de seguridad y accesos.',
    70,
    false,
    'event_piloto_seguridad'
  ),
  (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Tecnica',
    'tecnica',
    'Soporte tecnico operativo.',
    60,
    false,
    'event_piloto_tecnica'
  ),
  (
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    'Emergencia',
    'emergencia',
    'Canal critico para SOS.',
    100,
    true,
    'event_piloto_emergencia'
  )
on conflict (id) do update
set
  name = excluded.name,
  code = excluded.code,
  description = excluded.description,
  priority = excluded.priority,
  is_emergency = excluded.is_emergency,
  livekit_room_name = excluded.livekit_room_name;

insert into public.event_participants (
  id,
  event_id,
  auth_user_id,
  display_name,
  phone,
  role,
  invite_code,
  invite_status,
  joined_at,
  accepted_at,
  invite_expires_at
)
values
  (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000101',
    'Coordinacion General',
    '+540000000001',
    'coordinator',
    'PILOTOADMIN123',
    'accepted',
    now(),
    now(),
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000102',
    'Equipo Seguridad',
    '+540000000002',
    'participant',
    'PILOTOSEGUR123',
    'accepted',
    now(),
    now(),
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000103',
    'Equipo Produccion',
    '+540000000003',
    'participant',
    'PILOTOPRODU123',
    'accepted',
    now(),
    now(),
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000104',
    'Supervisor Viewer',
    '+540000000004',
    'viewer',
    'PILOTOVIEW123',
    'accepted',
    now(),
    now(),
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000001',
    null,
    'Invitado Pendiente',
    null,
    'participant',
    'PILOTOPEND123',
    'pending',
    null,
    null,
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000101',
    '10000000-0000-0000-0000-000000000001',
    null,
    'Demo Coordinacion',
    null,
    'coordinator',
    'SATI26',
    'pending',
    null,
    null,
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000102',
    '10000000-0000-0000-0000-000000000001',
    null,
    'Marcos Seguridad',
    null,
    'participant',
    'MARCOS26',
    'pending',
    null,
    null,
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000103',
    '10000000-0000-0000-0000-000000000001',
    null,
    'Ana Produccion',
    null,
    'participant',
    'ANA26',
    'pending',
    null,
    null,
    now() + interval '7 days'
  ),
  (
    '30000000-0000-0000-0000-000000000104',
    '10000000-0000-0000-0000-000000000001',
    null,
    'Julia Tecnica',
    null,
    'coordinator',
    'JULIA26',
    'pending',
    null,
    null,
    now() + interval '7 days'
  )
on conflict (id) do update
set
  auth_user_id = excluded.auth_user_id,
  display_name = excluded.display_name,
  phone = excluded.phone,
  role = excluded.role,
  invite_code = excluded.invite_code,
  invite_status = excluded.invite_status,
  joined_at = excluded.joined_at,
  accepted_at = excluded.accepted_at,
  invite_expires_at = excluded.invite_expires_at,
  invite_revoked_at = null;

insert into public.channel_members (
  channel_id,
  participant_id,
  can_listen,
  can_talk,
  can_view_history
)
values
  -- Admin: todos los canales.
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', true, true, true),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', true, true, true),
  ('20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001', true, true, true),
  -- Seguridad: seguridad + emergencia.
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000002', true, true, true),
  -- Produccion: produccion + emergencia.
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000003', true, true, true),
  -- Viewer: escucha, no habla.
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004', true, false, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000004', true, false, true),
  -- Invitado pendiente: acceso minimo para que el checklist piloto no falle
  -- por una invitacion creada pero aun no aceptada.
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000005', true, false, true),
  -- Codigos simples para demo local con invitado anonimo.
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000101', true, true, true),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000101', true, true, true),
  ('20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000101', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000101', true, true, true),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000102', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000102', true, true, true),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000103', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000103', true, true, true),
  ('20000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000104', true, true, true),
  ('20000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000104', true, true, true)
on conflict (channel_id, participant_id) do update
set
  can_listen = excluded.can_listen,
  can_talk = excluded.can_talk,
  can_view_history = excluded.can_view_history;

insert into public.event_logs (
  event_id,
  participant_id,
  type,
  title,
  detail
)
values (
  '10000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'seed_created',
  'Seed MVP cargado',
  'Datos de prueba listos.'
);
