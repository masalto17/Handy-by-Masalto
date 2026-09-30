import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { PttMode, loadConfig } from '../src/config.js';

const base = {
  SUPABASE_URL: 'https://abc.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_test',
  HANDY_INVITE_CODE: 'abcd2345wxyz',
  HANDY_CHANNEL_ID: '00000000-0000-0000-0000-000000000001',
  HANDY_PTT_MODE: 'vox',
};

describe('loadConfig', () => {
  it('normaliza el codigo de invitacion a mayusculas', () => {
    assert.equal(loadConfig(base).inviteCode, 'ABCD2345WXYZ');
  });

  it('trae defaults utilizables sin tocar nada', () => {
    const config = loadConfig(base);
    assert.equal(config.audioInDevice, 'default');
    assert.ok(config.maxKeyMs > config.leadMs);
  });

  it('exige lo que no puede inventar', () => {
    for (const key of [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'HANDY_INVITE_CODE',
      'HANDY_CHANNEL_ID',
    ]) {
      const env = { ...base, [key]: '' };
      assert.throws(() => loadConfig(env), new RegExp(key));
    }
  });

  it('rechaza un modo de PTT que no existe', () => {
    assert.throws(
      () => loadConfig({ ...base, HANDY_PTT_MODE: 'magia' }),
      /HANDY_PTT_MODE/,
    );
  });

  it('en modo command exige los dos comandos', () => {
    // Con uno solo, el puente sabria encender el transmisor y no apagarlo:
    // dejaria el canal tomado para todo el evento.
    assert.throws(
      () =>
        loadConfig({
          ...base,
          HANDY_PTT_MODE: PttMode.command,
          HANDY_PTT_KEY_CMD: 'gpioset 0 17=1',
        }),
      /HANDY_PTT_UNKEY_CMD/,
    );
  });

  it('rechaza un numero que no es numero', () => {
    assert.throws(
      () => loadConfig({ ...base, HANDY_TAIL_MS: 'mucho' }),
      /HANDY_TAIL_MS/,
    );
  });

  it('rechaza umbrales de squelch invertidos', () => {
    assert.throws(
      () =>
        loadConfig({
          ...base,
          HANDY_SQUELCH_OPEN: '0.05',
          HANDY_SQUELCH_CLOSE: '0.5',
        }),
      /HANDY_SQUELCH_CLOSE/,
    );
  });

  it('rechaza un tiempo maximo menor que la cola de apertura', () => {
    assert.throws(
      () =>
        loadConfig({ ...base, HANDY_LEAD_MS: '5000', HANDY_MAX_KEY_MS: '4000' }),
      /HANDY_MAX_KEY_MS/,
    );
  });
});
