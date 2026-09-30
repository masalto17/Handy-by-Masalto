import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { FrameChunker } from '../src/radio-io.js';

/** Buffer PCM16 con muestras 0,1,2,... para poder seguir el orden. */
function pcm(count, start = 0) {
  const buffer = Buffer.alloc(count * 2);
  for (let i = 0; i < count; i += 1) buffer.writeInt16LE(start + i, i * 2);
  return buffer;
}

describe('FrameChunker', () => {
  it('devuelve bloques completos', () => {
    const chunker = new FrameChunker(4);
    const frames = chunker.push(pcm(8));
    assert.equal(frames.length, 2);
    assert.deepEqual(Array.from(frames[0]), [0, 1, 2, 3]);
    assert.deepEqual(Array.from(frames[1]), [4, 5, 6, 7]);
  });

  it('guarda el resto hasta completar el bloque', () => {
    const chunker = new FrameChunker(4);
    // ALSA no respeta el limite de bloque: parte por donde le toca.
    assert.equal(chunker.push(pcm(3)).length, 0);
    const frames = chunker.push(pcm(1, 3));
    assert.equal(frames.length, 1);
    assert.deepEqual(Array.from(frames[0]), [0, 1, 2, 3]);
  });

  it('no pierde muestras entre llamadas sucesivas', () => {
    const chunker = new FrameChunker(4);
    const all = [];
    for (let i = 0; i < 10; i += 1) {
      for (const frame of chunker.push(pcm(3, i * 3))) {
        all.push(...frame);
      }
    }
    // 30 muestras entran en 7 bloques de 4; las 2 ultimas quedan pendientes.
    assert.deepEqual(all, Array.from({ length: 28 }, (_, i) => i));
  });

  it('aguanta un bloque vacio', () => {
    const chunker = new FrameChunker(4);
    assert.deepEqual(chunker.push(Buffer.alloc(0)), []);
  });

  it('conserva muestras negativas', () => {
    const chunker = new FrameChunker(2);
    const buffer = Buffer.alloc(4);
    buffer.writeInt16LE(-32768, 0);
    buffer.writeInt16LE(-1, 2);
    assert.deepEqual(Array.from(chunker.push(buffer)[0]), [-32768, -1]);
  });
});
