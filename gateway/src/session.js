import { createClient } from '@supabase/supabase-js';

/**
 * Entra al evento como un participante mas.
 *
 * El puente no usa una via privilegiada: se une con un codigo de invitacion,
 * igual que un celular. Asi el `service_role` nunca sale del backend, las
 * mismas reglas de RLS lo alcanzan, y el operador lo ve en la lista de
 * presencia con el nombre que le puso el admin — que es lo que necesita para
 * saber que el enlace con los handies esta arriba.
 *
 * @param {ReturnType<typeof import('./config.js').loadConfig>} config
 */
export async function joinChannel(config) {
  const client = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: { persistSession: false, autoRefreshToken: true },
  });

  const { error: authError } = await client.auth.signInAnonymously();
  if (authError) {
    throw new Error(`No se pudo autenticar: ${authError.message}`);
  }

  const { data: invite, error: inviteError } = await client.rpc(
    'accept_event_invite',
    { invite_code_input: config.inviteCode },
  );
  if (inviteError) {
    throw new Error(`Codigo rechazado: ${inviteError.message}`);
  }
  const participantId = readField(invite, 'participant_id');
  if (!participantId) {
    const serverMessage = readField(invite, 'error');
    throw new Error(
      serverMessage
        ? `Codigo rechazado: ${serverMessage}`
        : 'El codigo de invitacion no corresponde a ningun evento activo.',
    );
  }

  const { data: token, error: tokenError } = await client.functions.invoke(
    'livekit-token',
    { body: { channel_id: config.channelId } },
  );
  if (tokenError) {
    throw new Error(`No se pudo pedir el token de audio: ${tokenError.message}`);
  }
  if (!token?.participant_token) {
    throw new Error('La respuesta de livekit-token vino sin token.');
  }
  if (!token.can_publish_audio) {
    // Sin permiso de publicar, el puente escucharia a la sala pero los
    // handies no entrarian: es una instalacion a medias, y es mejor que
    // falle al arrancar que en el evento.
    throw new Error(
      'El participante del puente no tiene permiso para transmitir audio. ' +
        'Revisar su rol en el panel de admin.',
    );
  }

  return {
    client,
    participantId,
    serverUrl: token.server_url,
    token: token.participant_token,
    roomName: token.room_name,
  };
}

function readField(response, key) {
  if (typeof response === 'string') {
    return key === 'participant_id' ? response : null;
  }
  if (Array.isArray(response)) {
    return response.length > 0 ? readField(response[0], key) : null;
  }
  if (response && typeof response === 'object') {
    const value = response[key];
    return typeof value === 'string' && value.length > 0 ? value : null;
  }
  return null;
}
