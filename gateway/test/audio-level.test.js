import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { SquelchGate, rms } from '../src/audio-level.js';

/** Bloque de tono constante, para no depender de audio real. */
function block(amplitude, length = 256) {
  const samples = new Int16Array(length);
  samples.fill(Math.round(amplitude * 32767));
  return samples;
}

describe('rms', () => {
  it('da 0 en silencio', () => {
    assert.equal(rms(new Int16Array(128)), 0);
  });

  it('da el nivel de un bloque constante', () => {
    assert.ok(Math.abs(rms(block(0.5)) - 0.5) < 0.001);
  });

  it('no divide por cero con un bloque vacio', () => {
    assert.equal(rms(new Int16Array(0)), 0);
  });
});

describe('SquelchGate', () => {
  const gate = () =>
    new SquelchGate({ openLevel: 0.1, closeLevel: 0.05, hangMs: 300 });

  it('no abre con ruido de fondo', () => {
    assert.equal(gate().update(0.02, 0), false);
  });

  it('abre cuando hay voz', () => {
    assert.equal(gate().update(0.3, 0), true);
  });

  it('sostiene durante la pausa entre palabras', () => {
    const squelch = gate();
    squelch.update(0.3, 0);
    // Silencio de 200 ms: una pausa normal del habla, no el fin del mensaje.
    assert.equal(squelch.update(0.0, 200), true);
  });

  it('cierra cuando el silencio supera la cola', () => {
    const squelch = gate();
    squelch.update(0.3, 0);
    assert.equal(squelch.update(0.0, 300), false);
  });

  it('se sostiene en la histeresis sin castañetear', () => {
    const squelch = gate();
    squelch.update(0.3, 0);
    // Entre closeLevel y openLevel: con un solo umbral, este bloque habria
    // empezado a cerrar y cortaria silabas.
    assert.equal(squelch.update(0.07, 1000), true);
    assert.equal(squelch.update(0.07, 2000), true);
  });

  it('exige umbrales coherentes', () => {
    assert.throws(
      () => new SquelchGate({ openLevel: 0.1, closeLevel: 0.2, hangMs: 10 }),
      /closeLevel/,
    );
    assert.throws(() => new SquelchGate({ openLevel: 0, hangMs: 10 }), /openLevel/);
  });
});
