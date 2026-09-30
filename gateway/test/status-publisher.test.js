import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { StatusPublisher } from '../src/status-publisher.js';

function recorder() {
  const sent = [];
  return { sent, publish: async (attributes) => void sent.push(attributes) };
}

describe('StatusPublisher', () => {
  it('publica el estado y la cuenta de cortes', async () => {
    const log = recorder();
    const publisher = new StatusPublisher({ publish: log.publish });

    await publisher.update({ state: 'keyed', timeouts: 2 });

    assert.deepEqual(log.sent, [
      { bridge_state: 'keyed', bridge_timeouts: '2' },
    ]);
  });

  it('no reenvia un estado que no cambio', async () => {
    const log = recorder();
    const publisher = new StatusPublisher({ publish: log.publish });

    // El puente cambia de estado varias veces por segundo: reenviar lo mismo
    // seria trafico constante sobre la red del predio.
    await publisher.update({ state: 'idle', timeouts: 0 });
    await publisher.update({ state: 'idle', timeouts: 0 });
    await publisher.update({ state: 'idle', timeouts: 0 });

    assert.equal(log.sent.length, 1);
  });

  it('reenvia cuando cambia solo la cuenta de cortes', async () => {
    const log = recorder();
    const publisher = new StatusPublisher({ publish: log.publish });

    await publisher.update({ state: 'idle', timeouts: 0 });
    await publisher.update({ state: 'idle', timeouts: 1 });

    assert.equal(log.sent.length, 2);
  });

  it('mantiene el orden aunque un envio tarde mas', async () => {
    const sent = [];
    const publisher = new StatusPublisher({
      publish: async (attributes) => {
        if (attributes.bridge_state === 'keyed') {
          await new Promise((resolve) => setTimeout(resolve, 20));
        }
        sent.push(attributes.bridge_state);
      },
    });

    const first = publisher.update({ state: 'keyed', timeouts: 0 });
    const second = publisher.update({ state: 'idle', timeouts: 0 });
    await Promise.all([first, second]);

    // Al reves, la app quedaria mostrando "saliendo al aire" con el
    // transmisor ya apagado.
    assert.deepEqual(sent, ['keyed', 'idle']);
  });

  it('un fallo no tumba el puente y permite reintentar', async () => {
    const errors = [];
    let shouldFail = true;
    const sent = [];
    const publisher = new StatusPublisher({
      publish: async (attributes) => {
        if (shouldFail) throw new Error('sin permiso');
        sent.push(attributes);
      },
      onError: (message) => errors.push(message),
    });

    await publisher.update({ state: 'idle', timeouts: 0 });
    assert.equal(errors.length, 1);

    // El estado fallido no queda cacheado: si no, el mismo estado nunca
    // volveria a intentarse y la app se quedaria sin informacion.
    shouldFail = false;
    await publisher.update({ state: 'idle', timeouts: 0 });
    assert.equal(sent.length, 1);
  });
});
