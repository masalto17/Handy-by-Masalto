import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type VoiceMessageRow = {
  id: string;
  event_id: string;
  channel_id: string;
  storage_path: string | null;
  transcription_status: string;
};

type SupabaseClientAny = ReturnType<typeof createClient<any, "public", any>>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Metodo no permitido." }, 405);
  }

  try {
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const supabaseAnonKey = requiredEnv("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const localWhisperUrl = Deno.env.get("LOCAL_WHISPER_URL")?.trim();
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY")?.trim();
    const transcriptionModel = Deno.env.get("OPENAI_TRANSCRIPTION_MODEL") ??
      "gpt-4o-mini-transcribe";
    if (!localWhisperUrl && !openAiApiKey) {
      throw new Error("Falta configurar LOCAL_WHISPER_URL u OPENAI_API_KEY.");
    }
    const authorization = request.headers.get("Authorization");

    if (!authorization) {
      return jsonResponse({ error: "Falta Authorization." }, 401);
    }

    const body = await request.json().catch(() => ({}));
    const channelId = String(body.channel_id ?? "").trim();
    const messageIds = Array.isArray(body.message_ids)
      ? body.message_ids
        .map((id: unknown) => String(id).trim())
        .filter((id: string) => id.length > 0)
      : [];
    const limit = Math.min(Number(body.limit ?? 8), 20);
    if (!channelId) {
      return jsonResponse({ error: "Falta channel_id." }, 400);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: visibleMessages, error: visibleError } = await userClient
      .from("voice_messages")
      .select("id")
      .eq("channel_id", channelId)
      .limit(1);

    if (visibleError) {
      return jsonResponse({ error: visibleError.message }, 403);
    }
    if (!visibleMessages) {
      return jsonResponse({ error: "Canal no disponible." }, 403);
    }

    let messagesQuery = adminClient
      .from("voice_messages")
      .select("id,event_id,channel_id,storage_path,transcription_status")
      .eq("channel_id", channelId)
      .in("transcription_status", ["pending", "failed"])
      .not("storage_path", "is", null)
      .order("created_at", { ascending: true });

    if (messageIds.length > 0) {
      messagesQuery = messagesQuery.in("id", messageIds);
    } else {
      messagesQuery = messagesQuery.limit(limit);
    }

    const { data: messages, error: queryError } = await messagesQuery;

    if (queryError) {
      return jsonResponse({ error: queryError.message }, 500);
    }

    let transcribedCount = 0;
    const failedIds: string[] = [];
    let firstFailureMessage: string | null = null;

    for (const message of (messages ?? []) as VoiceMessageRow[]) {
      try {
        const provider = localWhisperUrl ? "whisper_cpp_local" : "openai";
        await markProcessing(adminClient, message.id, provider);
        const audio = await downloadAudio(adminClient, message.storage_path!);
        const transcript = localWhisperUrl
          ? await transcribeWithLocalWhisper({
            serviceUrl: localWhisperUrl,
            audio,
            filename: filenameFor(message.storage_path!),
          })
          : await transcribeWithOpenAi({
            apiKey: openAiApiKey!,
            model: transcriptionModel,
            audio,
            filename: filenameFor(message.storage_path!),
          });

        const { error: updateError } = await adminClient
          .from("voice_messages")
          .update({
            transcription_text: transcript,
            transcription_status: "completed",
            transcription_provider: provider,
            transcription_job_id: `${provider}:${message.id}`,
          })
          .eq("id", message.id);

        if (updateError) throw updateError;
        transcribedCount++;
      } catch (error) {
        const failureMessage = errorMessage(error);
        firstFailureMessage ??= failureMessage;
        failedIds.push(message.id);
        await adminClient
          .from("voice_messages")
          .update({
            transcription_status: "failed",
            transcription_provider: localWhisperUrl
              ? "whisper_cpp_local"
              : "openai",
            transcription_job_id: localWhisperUrl
              ? `whisper_cpp_local:${message.id}`
              : `openai:${message.id}`,
          })
          .eq("id", message.id);
        console.error("transcribe-audio failed", message.id, failureMessage);
      }
    }

    return jsonResponse({
      transcribed_count: transcribedCount,
      failed_count: failedIds.length,
      failed_ids: failedIds,
      error: firstFailureMessage,
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
  if (!value) {
    throw new Error(`Falta configurar ${name}.`);
  }
  return value;
}

async function markProcessing(
  client: SupabaseClientAny,
  id: string,
  provider: string,
) {
  const { error } = await client
    .from("voice_messages")
    .update({
      transcription_status: "processing",
      transcription_provider: provider,
      transcription_job_id: `${provider}:${id}`,
    })
    .eq("id", id)
    .in("transcription_status", ["pending", "failed"]);

  if (error) throw error;
}

async function downloadAudio(
  client: SupabaseClientAny,
  storagePath: string,
): Promise<Blob> {
  const { data, error } = await client.storage
    .from("event-audio")
    .download(storagePath);

  if (error) throw error;
  if (!data) throw new Error("Audio no encontrado en Storage.");
  return data;
}

async function transcribeWithLocalWhisper({
  serviceUrl,
  audio,
  filename,
}: {
  serviceUrl: string;
  audio: Blob;
  filename: string;
}): Promise<string> {
  const formData = new FormData();
  formData.append("file", audio, filename);

  const response = await fetch(serviceUrl, {
    method: "POST",
    body: formData,
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const result = await response.json();
  const text = String(result.text ?? "").trim();
  if (!text) {
    throw new Error("Whisper local no devolvio texto de transcripcion.");
  }
  return text;
}

async function transcribeWithOpenAi({
  apiKey,
  model,
  audio,
  filename,
}: {
  apiKey: string;
  model: string;
  audio: Blob;
  filename: string;
}): Promise<string> {
  const formData = new FormData();
  formData.append("model", model);
  formData.append("file", audio, filename);
  formData.append("language", "es");

  const response = await fetch(
    "https://api.openai.com/v1/audio/transcriptions",
    {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}` },
      body: formData,
    },
  );

  if (!response.ok) {
    throw new Error(await response.text());
  }

  const result = await response.json();
  const text = String(result.text ?? "").trim();
  if (!text) {
    throw new Error("OpenAI no devolvio texto de transcripcion.");
  }
  return text;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return readableOpenAiError(error.message);
  }
  return readableOpenAiError(String(error));
}

function readableOpenAiError(message: string): string {
  try {
    const parsed = JSON.parse(message);
    const providerMessage = parsed?.error?.message;
    if (typeof providerMessage === "string" && providerMessage.trim()) {
      return providerMessage.trim();
    }
  } catch (_) {
    // Not a JSON provider error.
  }
  return message.trim() || "Error de transcripcion.";
}

function filenameFor(storagePath: string): string {
  return storagePath.split("/").at(-1) || "audio.wav";
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
