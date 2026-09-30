import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ArbiterState, RadioArbiter } from '../src/radio-arbiter.js';

const arbiter = () =>
  new RadioArbiter({
    leadMs: 200,
    tailMs: 400,
    maxKeyMs: 60_000,
    lockoutMs: 2_000,
  });

const quiet = { roomActive: false, radioActive: false };

describe('RadioArbiter', () => {
  it('en reposo no toca el transmisor', () => {
    const out = arbiter().update({ ...quiet, nowMs: 0 });
    assert.equal(out.keyed, false);
    assert.equal(out.sendAudioToRadio, false);
    assert.equal(out.publishRadioAudio, false);
  });

  it('enciende el transmisor antes de mandar audio', () => {
    const bridge = arbiter();
    const start = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 0,
    });
    // El transmisor levanta primero: mandar audio en este instante es
    // perder la primera silaba.
    assert.equal(start.keyed, true);
    assert.equal(start.sendAudioToRadio, false);

    const ready = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 200,
    });
    assert.equal(ready.sendAudioToRadio, true);
  });

  it('sostiene la portadora despues de la ultima palabra', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: true, radioActive: false, nowMs: 0 });
    bridge.update({ roomActive: true, radioActive: false, nowMs: 300 });

    const tail = bridge.update({ ...quiet, nowMs: 500 });
    assert.equal(tail.keyed, true);
    assert.equal(tail.state, ArbiterState.tail);

    const done = bridge.update({ ...quiet, nowMs: 700 });
    assert.equal(done.keyed, false);
    assert.equal(done.state, ArbiterState.idle);
  });

  it('no transmite mientras un handy tiene el canal', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: false, radioActive: true, nowMs: 0 });

    // Alguien de la sala aprieta PTT en medio de la transmision del handy:
    // pisarla es justamente lo que no puede pasar.
    const out = bridge.update({
      roomActive: true,
      radioActive: true,
      nowMs: 100,
    });
    assert.equal(out.keyed, false);
    assert.equal(out.state, ArbiterState.receiving);
    assert.equal(out.publishRadioAudio, true);
  });

  it('nunca publica el audio del radio mientras transmite', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: true, radioActive: false, nowMs: 0 });

    // Con el transmisor encendido, lo que capta el receptor es la propia
    // transmision: publicarlo seria realimentacion.
    const out = bridge.update({
      roomActive: true,
      radioActive: true,
      nowMs: 300,
    });
    assert.equal(out.keyed, true);
    assert.equal(out.publishRadioAudio, false);
  });

  it('toma el canal apenas el handy lo suelta', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: false, radioActive: true, nowMs: 0 });
    const out = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 500,
    });
    assert.equal(out.state, ArbiterState.keying);
    assert.equal(out.keyed, true);
  });

  it('corta una transmision trabada al llegar al tiempo maximo', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: true, radioActive: false, nowMs: 0 });

    const out = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 60_000,
    });
    assert.equal(out.keyed, false);
    assert.equal(out.state, ArbiterState.lockout);
    assert.equal(bridge.timeouts, 1);
  });

  it('no vuelve a tomar el canal en el acto despues del corte', () => {
    const bridge = arbiter();
    bridge.update({ roomActive: true, radioActive: false, nowMs: 0 });
    bridge.update({ roomActive: true, radioActive: false, nowMs: 60_000 });

    const during = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 61_000,
    });
    assert.equal(during.keyed, false);

    const after = bridge.update({
      roomActive: true,
      radioActive: false,
      nowMs: 62_000,
    });
    assert.equal(after.keyed, true);
  });

  it('una transmision continua no se corta antes de tiempo', () => {
    const bridge = arbiter();
    let out = bridge.update({ roomActive: true, radioActive: false, nowMs: 0 });
    for (let t = 100; t <= 59_000; t += 100) {
      out = bridge.update({ roomActive: true, radioActive: false, nowMs: t });
    }
    assert.equal(out.keyed, true);
    assert.equal(out.sendAudioToRadio, true);
    assert.equal(bridge.timeouts, 0);
  });

  it('rechaza una configuracion imposible', () => {
    assert.throws(
      () =>
        new RadioArbiter({
          leadMs: 500,
          tailMs: 100,
          maxKeyMs: 400,
          lockoutMs: 0,
        }),
      /maxKeyMs/,
    );
    assert.throws(
      () =>
        new RadioArbiter({
          leadMs: -1,
          tailMs: 100,
          maxKeyMs: 400,
          lockoutMs: 0,
        }),
      /leadMs/,
    );
  });
});
