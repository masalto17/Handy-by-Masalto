import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { PttMode } from '../src/config.js';
import { PttKeyer } from '../src/ptt-keyer.js';

function recorder() {
  const commands = [];
  return {
    commands,
    run: async (command) => {
      commands.push(command);
    },
  };
}

const options = (extra = {}) => ({
  mode: PttMode.command,
  keyCommand: 'KEY',
  unkeyCommand: 'UNKEY',
  ...extra,
});

describe('PttKeyer', () => {
  it('enciende y apaga el transmisor', async () => {
    const log = recorder();
    const keyer = new PttKeyer(options({ run: log.run }));

    await keyer.setKeyed(true);
    await keyer.setKeyed(false);

    assert.deepEqual(log.commands, ['KEY', 'UNKEY']);
  });

  it('no repite el comando si el estado no cambio', async () => {
    const log = recorder();
    const keyer = new PttKeyer(options({ run: log.run }));

    await keyer.setKeyed(true);
    await keyer.setKeyed(true);
    await keyer.setKeyed(true);

    assert.deepEqual(log.commands, ['KEY']);
  });

  it('mantiene el orden aunque los comandos tarden distinto', async () => {
    const commands = [];
    const keyer = new PttKeyer(
      options({
        run: async (command) => {
          // El de encendido tarda mas: sin cola, el apagado terminaria
          // primero y el transmisor quedaria encendido.
          if (command === 'KEY') {
            await new Promise((resolve) => setTimeout(resolve, 20));
          }
          commands.push(command);
        },
      }),
    );

    const first = keyer.setKeyed(true);
    const second = keyer.setKeyed(false);
    await Promise.all([first, second]);

    assert.deepEqual(commands, ['KEY', 'UNKEY']);
  });

  it('un comando que falla no tumba el puente', async () => {
    const errors = [];
    const keyer = new PttKeyer(
      options({
        run: async () => {
          throw new Error('gpioset: no such device');
        },
        onError: (message) => errors.push(message),
      }),
    );

    await keyer.setKeyed(true);
    assert.equal(errors.length, 1);
  });

  it('en modo VOX no ejecuta nada', async () => {
    const log = recorder();
    const keyer = new PttKeyer(options({ mode: PttMode.vox, run: log.run }));

    await keyer.setKeyed(true);
    await keyer.release();

    assert.deepEqual(log.commands, []);
  });

  it('release apaga aunque el puente se creyera apagado', async () => {
    const log = recorder();
    const keyer = new PttKeyer(options({ run: log.run }));

    // Al salir hay que apagar igual: si el proceso murio con el transmisor
    // encendido, el canal queda mudo para todo el evento.
    await keyer.release();

    assert.deepEqual(log.commands, ['UNKEY']);
  });
});
