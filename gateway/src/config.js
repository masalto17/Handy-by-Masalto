/**
 * Configuracion del puente, leida del entorno.
 *
 * Se valida entera al arrancar y no sobre la marcha: un puente que arranca
 * y recien falla cuando alguien aprieta PTT falla en el peor momento, que
 * es durante el evento.
 */

/** Frecuencia de muestreo del puente. Voz de radio; 16 kHz sobra. */
export const SAMPLE_RATE = 16_000;

/** Duracion de cada bloque de audio, en ms. */
export const FRAME_MS = 20;

/** Muestras por bloque. */
export const FRAME_SAMPLES = (SAMPLE_RATE * FRAME_MS) / 1000;

/** Modos de accionamiento del PTT del handy. */
export const PttMode = {
  /**
   * El handy transmite solo, al detectar audio en su entrada (VOX).
   * No hace falta cablear nada mas, pero recorta el arranque de cada frase
   * y no se puede cortar una transmision trabada desde el puente.
   */
  vox: 'vox',
  /**
   * El puente acciona el PTT con un comando (GPIO, rele, rigctl).
   * Es el modo recomendado: control real del transmisor.
   */
  command: 'command',
};

function requiredString(env, name) {
  const value = (env[name] ?? '').trim();
  if (!value) throw new Error(`Falta configurar ${name}.`);
  return value;
}

function number(env, name, fallback, { min = 0, max = Infinity } = {}) {
  const raw = (env[name] ?? '').trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    throw new Error(`${name} tiene que ser un numero: "${raw}".`);
  }
  if (value < min || value > max) {
    throw new Error(`${name} tiene que estar entre ${min} y ${max}.`);
  }
  return value;
}

/**
 * Arma la configuracion a partir del entorno.
 *
 * @param {Record<string, string | undefined>} env
 */
export function loadConfig(env = process.env) {
  const pttMode = (env.HANDY_PTT_MODE ?? PttMode.command).trim();
  if (!Object.values(PttMode).includes(pttMode)) {
    throw new Error(
      `HANDY_PTT_MODE tiene que ser "${PttMode.vox}" o "${PttMode.command}".`,
    );
  }

  const config = {
    supabaseUrl: requiredString(env, 'SUPABASE_URL'),
    supabaseAnonKey: requiredString(env, 'SUPABASE_ANON_KEY'),
    inviteCode: requiredString(env, 'HANDY_INVITE_CODE').toUpperCase(),
    channelId: requiredString(env, 'HANDY_CHANNEL_ID'),

    audioInDevice: (env.HANDY_AUDIO_IN ?? 'default').trim(),
    audioOutDevice: (env.HANDY_AUDIO_OUT ?? 'default').trim(),

    pttMode,
    pttKeyCommand: (env.HANDY_PTT_KEY_CMD ?? '').trim(),
    pttUnkeyCommand: (env.HANDY_PTT_UNKEY_CMD ?? '').trim(),

    squelchOpenLevel: number(env, 'HANDY_SQUELCH_OPEN', 0.06, { max: 1 }),
    squelchCloseLevel: number(env, 'HANDY_SQUELCH_CLOSE', 0.03, { max: 1 }),
    squelchHangMs: number(env, 'HANDY_SQUELCH_HANG_MS', 600),

    // El audio de la sala ya viene abierto/cerrado por el PTT de cada
    // celular, pero un microfono abierto en un bolsillo manda ruido: el
    // mismo umbral evita que eso tome el canal de aire.
    roomOpenLevel: number(env, 'HANDY_ROOM_OPEN', 0.02, { max: 1 }),
    roomHangMs: number(env, 'HANDY_ROOM_HANG_MS', 400),

    leadMs: number(env, 'HANDY_LEAD_MS', 250),
    tailMs: number(env, 'HANDY_TAIL_MS', 400),
    maxKeyMs: number(env, 'HANDY_MAX_KEY_MS', 120_000, { min: 1_000 }),
    lockoutMs: number(env, 'HANDY_LOCKOUT_MS', 3_000),
  };

  if (config.squelchCloseLevel > config.squelchOpenLevel) {
    throw new Error('HANDY_SQUELCH_CLOSE no puede superar a HANDY_SQUELCH_OPEN.');
  }
  if (config.maxKeyMs <= config.leadMs) {
    throw new Error('HANDY_MAX_KEY_MS tiene que superar a HANDY_LEAD_MS.');
  }
  if (config.pttMode === PttMode.command) {
    if (!config.pttKeyCommand || !config.pttUnkeyCommand) {
      throw new Error(
        'Con HANDY_PTT_MODE=command hay que definir HANDY_PTT_KEY_CMD y ' +
          'HANDY_PTT_UNKEY_CMD.',
      );
    }
  }

  return config;
}
