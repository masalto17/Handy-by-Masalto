import { spawn } from 'node:child_process';

import { FRAME_SAMPLES, SAMPLE_RATE } from './config.js';

/**
 * Corta un flujo de bytes PCM16 en bloques de tamaño fijo.
 *
 * ALSA entrega los bytes como vienen, sin respetar el limite de bloque, y
 * un bloque a medio llenar convertido a muestras suena como un chasquido.
 */
export class FrameChunker {
  /** @param {number} samplesPerFrame */
  constructor(samplesPerFrame = FRAME_SAMPLES) {
    this.bytesPerFrame = samplesPerFrame * 2;
    this._pending = Buffer.alloc(0);
  }

  /**
   * Agrega bytes y devuelve los bloques completos que quedaron.
   *
   * @param {Buffer} chunk
   * @returns {Int16Array[]}
   */
  push(chunk) {
    this._pending =
      this._pending.length === 0
        ? Buffer.from(chunk)
        : Buffer.concat([this._pending, chunk]);

    const frames = [];
    let offset = 0;
    while (this._pending.length - offset >= this.bytesPerFrame) {
      const slice = this._pending.subarray(offset, offset + this.bytesPerFrame);
      // Copia: la vista apunta al buffer acumulado, que se descarta abajo.
      const samples = new Int16Array(this.bytesPerFrame / 2);
      for (let i = 0; i < samples.length; i += 1) {
        samples[i] = slice.readInt16LE(i * 2);
      }
      frames.push(samples);
      offset += this.bytesPerFrame;
    }
    this._pending = this._pending.subarray(offset);
    return frames;
  }
}

/** Argumentos comunes de ALSA para audio de voz mono. */
function alsaArgs(device) {
  return [
    '-D', device,
    '-f', 'S16_LE',
    '-r', String(SAMPLE_RATE),
    '-c', '1',
    '-t', 'raw',
    '-q',
  ];
}

/**
 * Captura audio del receptor del handy.
 *
 * @param {object} options
 * @param {string} options.device
 * @param {(frame: Int16Array) => void} options.onFrame
 * @param {(message: string, error?: unknown) => void} options.onError
 */
export function startCapture({ device, onFrame, onError }) {
  const process = spawn('arecord', alsaArgs(device), {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const chunker = new FrameChunker();

  process.stdout.on('data', (chunk) => {
    for (const frame of chunker.push(chunk)) onFrame(frame);
  });
  process.stderr.on('data', (data) => onError(`arecord: ${data}`.trim()));
  process.on('error', (error) => onError('No se pudo ejecutar arecord.', error));
  process.on('exit', (code) => {
    if (code !== 0 && code !== null) {
      onError(`arecord termino con codigo ${code}.`);
    }
  });

  return process;
}

/**
 * Reproduce audio hacia la entrada de microfono del handy.
 *
 * @param {object} options
 * @param {string} options.device
 * @param {(message: string, error?: unknown) => void} options.onError
 */
export function startPlayback({ device, onError }) {
  const process = spawn('aplay', alsaArgs(device), {
    stdio: ['pipe', 'ignore', 'pipe'],
  });

  process.stderr.on('data', (data) => onError(`aplay: ${data}`.trim()));
  process.on('error', (error) => onError('No se pudo ejecutar aplay.', error));
  // Un EPIPE al salir es normal y no merece ruido en el log.
  process.stdin.on('error', () => {});

  return {
    process,
    /** @param {Int16Array} frame */
    write(frame) {
      if (process.stdin.destroyed) return;
      process.stdin.write(Buffer.from(frame.buffer, frame.byteOffset, frame.byteLength));
    },
  };
}
