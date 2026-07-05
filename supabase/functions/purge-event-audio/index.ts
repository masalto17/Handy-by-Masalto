// Purga el audio de eventos cerrados/cancelados hace mas de N dias.
// Mantiene el storage dentro del free tier y cumple la politica de
// privacidad: el audio de un evento no vive para siempre.
//
// Ejecutar con service role, idealmente agendada (Supabase Dashboard →
// Edge Functions → Schedules, o pg_cron + pg_net). Sin parametros usa
// RETENTION_DAYS (default 30).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_RETENTION_DAYS = 30;
const BATCH_SIZE = 100;

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Metodo no permitido." }, 405);
  }

  try {
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    // Solo service role puede invocarla: se exige el secret como Bearer.
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.endsWith(serviceRoleKey)) {
      return jsonResponse({ error: "No autorizado." }, 401);
    }

    const body = await request.json().catch(() => ({}));
    const retentionDays = Number(
      body.retention_days ??
        Deno.env.get("RETENTION_DAYS") ??
        DEFAULT_RETENTION_DAYS,
    );
    const cutoff = new Date(
      Date.now() - retentionDays * 24 * 60 * 60 * 1000,
    ).toISOString();

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // Eventos cerrados/cancelados cuya finalizacion supero la retencion.
    const { data: expiredEvents, error: eventsError } = await admin
      .from("events")
      .select("id")
      .in("status", ["closed", "cancelled"])
      .lt("ends_at", cutoff);

    if (eventsError) throw eventsError;

    let deletedFiles = 0;
    let clearedMessages = 0;

    for (const event of expiredEvents ?? []) {
      const { data: messages, error: messagesError } = await admin
        .from("voice_messages")
        .select("id,storage_path")
        .eq("event_id", event.id)
        .not("storage_path", "is", null)
        .limit(BATCH_SIZE);

      if (messagesError) throw messagesError;
      if (!messages || messages.length === 0) continue;

      const paths = messages
        .map((message) => message.storage_path as string)
        .filter((path) => path.length > 0);

      if (paths.length > 0) {
        const { error: removeError } = await admin.storage
          .from("event-audio")
          .remove(paths);
        if (removeError) throw removeError;
        deletedFiles += paths.length;
      }

      const { error: clearError } = await admin
        .from("voice_messages")
        .update({ storage_path: null, audio_url: null })
        .in("id", messages.map((message) => message.id));
      if (clearError) throw clearError;
      clearedMessages += messages.length;
    }

    return jsonResponse({
      retention_days: retentionDays,
      expired_events: (expiredEvents ?? []).length,
      deleted_files: deletedFiles,
      cleared_messages: clearedMessages,
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Error inesperado.";
    return jsonResponse({ error: message }, 500);
  }
});

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Falta configurar ${name}.`);
  return value;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
