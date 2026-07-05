import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type TokenContext = {
  event_id: string;
  channel_id: string;
  channel_name: string;
  room_name: string;
  participant_id: string;
  participant_name: string;
  participant_role: string;
  can_publish_audio: boolean;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Metodo no permitido.' }, 405);
  }

  try {
    const liveKitUrl = requiredEnv('LIVEKIT_URL');
    const liveKitApiKey = requiredEnv('LIVEKIT_API_KEY');
    const liveKitApiSecret = requiredEnv('LIVEKIT_API_SECRET');
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const supabaseAnonKey = requiredEnv('SUPABASE_ANON_KEY');
    const authorization = request.headers.get('Authorization');

    if (!authorization) {
      return jsonResponse({ error: 'Falta Authorization.' }, 401);
    }

    const body = await request.json().catch(() => ({}));
    const channelId = String(body.channel_id ?? '').trim();
    if (!channelId) {
      return jsonResponse({ error: 'Falta channel_id.' }, 400);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });

    const { data, error } = await supabase.rpc('livekit_token_context', {
      target_channel_id: channelId,
    });

    if (error) {
      return jsonResponse({ error: error.message }, 403);
    }

    const context = data as TokenContext;
    const participantToken = await signLiveKitToken({
      apiKey: liveKitApiKey,
      apiSecret: liveKitApiSecret,
      context,
    });

    return jsonResponse(
      {
        server_url: liveKitUrl,
        participant_token: participantToken,
        room_name: context.room_name,
        can_publish_audio: context.can_publish_audio,
      },
      201,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Error inesperado.';
    return jsonResponse({ error: message }, 500);
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Falta configurar ${name}.`);
  }
  return value;
}

async function signLiveKitToken({
  apiKey,
  apiSecret,
  context,
}: {
  apiKey: string;
  apiSecret: string;
  context: TokenContext;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    iss: apiKey,
    sub: context.participant_id,
    name: context.participant_name,
    nbf: now - 10,
    exp: now + 10 * 60,
    metadata: JSON.stringify({
      event_id: context.event_id,
      channel_id: context.channel_id,
      role: context.participant_role,
    }),
    video: {
      room: context.room_name,
      roomJoin: true,
      canSubscribe: true,
      canPublish: context.can_publish_audio,
      canPublishData: false,
      ...(context.can_publish_audio
        ? { canPublishSources: ['microphone'] }
        : {}),
    },
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(apiSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(signature)}`;
}

function base64UrlEncode(value: string | ArrayBuffer): string {
  const bytes =
    typeof value === 'string'
      ? new TextEncoder().encode(value)
      : new Uint8Array(value);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll(
    '=',
    '',
  );
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
