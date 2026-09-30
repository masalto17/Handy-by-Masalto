import {
  AudioFrame,
  AudioMixer,
  AudioSource,
  AudioStream,
  LocalAudioTrack,
  Room,
  RoomEvent,
  TrackKind,
  TrackPublishOptions,
  TrackSource,
  dispose,
} from '@livekit/rtc-node';

import { SquelchGate, rms } from './audio-level.js';
import { FRAME_MS, FRAME_SAMPLES, SAMPLE_RATE, loadConfig } from './config.js';
import { PttKeyer } from './ptt-keyer.js';
import { RadioArbiter } from './radio-arbiter.js';
import { startCapture, startPlayback } from './radio-io.js';
import { StatusPublisher } from './status-publisher.js';
import { joinChannel } from './session.js';

const SILENCE = new Int16Array(FRAME_SAMPLES);

function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

function logError(message, error) {
  console.error(`[${new Date().toISOString()}] ${message}`);
  if (error) console.error(error);
}

async function main() {
  const config = loadConfig();
  log(`Entrando al canal ${config.channelId}...`);

  const session = await joinChannel(config);
  log(`Sala ${session.roomName} en ${session.serverUrl}`);

  const keyer = new PttKeyer({
    mode: config.pttMode,
    keyCommand: config.pttKeyCommand,
    unkeyCommand: config.pttUnkeyCommand,
    onError: logError,
  });

  const arbiter = new RadioArbiter({
    leadMs: config.leadMs,
    tailMs: config.tailMs,
    maxKeyMs: config.maxKeyMs,
    lockoutMs: config.lockoutMs,
  });

  const radioSquelch = new SquelchGate({
    openLevel: config.squelchOpenLevel,
    closeLevel: config.squelchCloseLevel,
    hangMs: config.squelchHangMs,
  });
  const roomGate = new SquelchGate({
    openLevel: config.roomOpenLevel,
    closeLevel: config.roomOpenLevel / 2,
    hangMs: config.roomHangMs,
  });

  // --- Sala -> handies -------------------------------------------------
  const playback = startPlayback({
    device: config.audioOutDevice,
    onError: logError,
  });
  const mixer = new AudioMixer(SAMPLE_RATE, 1, { blocksize: FRAME_SAMPLES });
  let latestRoomFrame = null;

  (async () => {
    for await (const frame of mixer) {
      latestRoomFrame = frame.data;
    }
  })().catch((error) => logError('Se corto el mezclador de la sala.', error));

  // --- Handies -> sala -------------------------------------------------
  const radioSource = new AudioSource(SAMPLE_RATE, 1);
  let radioActive = false;

  const capture = startCapture({
    device: config.audioInDevice,
    onError: logError,
    onFrame: (samples) => {
      radioActive = radioSquelch.update(rms(samples), now());
      if (!arbiter.snapshot().publishRadioAudio) return;
      radioSource
        .captureFrame(new AudioFrame(samples, SAMPLE_RATE, 1, samples.length))
        .catch((error) => logError('No se pudo publicar audio del radio.', error));
    },
  });

  // --- Sala ------------------------------------------------------------
  const room = new Room();

  room.on(RoomEvent.TrackSubscribed, (track) => {
    if (track.kind !== TrackKind.KIND_AUDIO) return;
    mixer.addStream(new AudioStream(track, SAMPLE_RATE, 1));
  });
  room.on(RoomEvent.Disconnected, () => {
    // Perder la sala con el transmisor encendido deja el canal de aire mudo
    // para todos los handies del evento, no solo para el puente.
    logError('Se perdio la sala: se apaga el transmisor.');
    keyer.release().catch((error) => logError('No se pudo apagar el PTT.', error));
  });
  room.on(RoomEvent.Reconnecting, () => log('Reconectando a la sala...'));
  room.on(RoomEvent.Reconnected, () => log('Sala reconectada.'));

  await room.connect(session.serverUrl, session.token, {
    autoSubscribe: true,
    dynacast: false,
  });
  log('Conectado a la sala.');

  const track = LocalAudioTrack.createAudioTrack('radio-uhf', radioSource);
  await room.localParticipant.publishTrack(
    track,
    new TrackPublishOptions({ source: TrackSource.SOURCE_MICROPHONE }),
  );
  log('Puente arriba. El audio del aire ya entra al canal.');

  const statusPublisher = new StatusPublisher({
    publish: (attributes) => room.localParticipant.setAttributes(attributes),
    onError: logError,
  });

  // --- Ciclo de arbitraje ----------------------------------------------
  let lastState = null;
  const ticker = setInterval(() => {
    const roomFrame = latestRoomFrame;
    latestRoomFrame = null;

    const roomActive = roomGate.update(
      roomFrame ? rms(roomFrame) : 0,
      now(),
    );
    const decision = arbiter.update({ roomActive, radioActive, nowMs: now() });

    if (decision.state !== lastState) {
      lastState = decision.state;
      log(`Canal: ${decision.state}`);
    }

    keyer
      .setKeyed(decision.keyed)
      .catch((error) => logError('No se pudo accionar el PTT.', error));

    statusPublisher
      .update({ state: decision.state, timeouts: arbiter.timeouts })
      .catch((error) => logError('No se pudo informar el estado.', error));

    playback.write(
      decision.sendAudioToRadio && roomFrame ? roomFrame : SILENCE,
    );
  }, FRAME_MS);

  const shutdown = async (signal) => {
    log(`Cerrando (${signal})...`);
    clearInterval(ticker);
    // Primero el transmisor: es lo unico que afecta a los demas equipos.
    await keyer.release().catch(() => {});
    capture.kill('SIGTERM');
    playback.process.kill('SIGTERM');
    await mixer.aclose().catch(() => {});
    await room.disconnect().catch(() => {});
    await session.client.auth.signOut().catch(() => {});
    dispose();
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

/** Reloj monotono: el del sistema puede saltar con NTP en medio del evento. */
function now() {
  return Number(process.hrtime.bigint() / 1_000_000n);
}

main().catch((error) => {
  logError('El puente no pudo arrancar.', error);
  process.exit(1);
});
