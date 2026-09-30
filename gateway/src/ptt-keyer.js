import { exec } from 'node:child_process';
import { promisify } from 'node:util';

import { PttMode } from './config.js';

const execAsync = promisify(exec);

/**
 * Acciona el PTT del handy.
 *
 * El comando se deja configurable en vez de hablarle a un GPIO concreto
 * porque el hardware cambia con cada instalacion: una Raspberry con
 * `gpioset`, un rele USB, `rigctl`. Lo que no cambia es que hay que poder
 * encender y apagar el transmisor.
 */
export class PttKeyer {
  /**
   * @param {object} options
   * @param {string} options.mode Ver {@link PttMode}.
   * @param {string} options.keyCommand
   * @param {string} options.unkeyCommand
   * @param {(command: string) => Promise<unknown>} [options.run] Inyectable
   *   para test.
   * @param {(message: string, error?: unknown) => void} [options.onError]
   */
  constructor({ mode, keyCommand, unkeyCommand, run, onError }) {
    this.mode = mode;
    this.keyCommand = keyCommand;
    this.unkeyCommand = unkeyCommand;
    this._run = run ?? ((command) => execAsync(command));
    this._onError = onError ?? (() => {});
    this.isKeyed = false;
    /** Cola de un solo carril: el orden encender/apagar no puede invertirse. */
    this._queue = Promise.resolve();
  }

  /**
   * Pide el estado del transmisor. Repetir el estado actual no ejecuta nada.
   *
   * @param {boolean} keyed
   * @returns {Promise<void>}
   */
  async setKeyed(keyed) {
    if (this.mode === PttMode.vox) return;
    if (keyed === this.isKeyed) return;
    this.isKeyed = keyed;

    const command = keyed ? this.keyCommand : this.unkeyCommand;
    // Encadenado, no en paralelo: dos comandos simultaneos pueden llegar al
    // GPIO al reves y dejar el transmisor encendido para siempre.
    this._queue = this._queue.then(async () => {
      try {
        await this._run(command);
      } catch (error) {
        this._onError(`Fallo el comando de PTT: ${command}`, error);
      }
    });
    return this._queue;
  }

  /**
   * Apaga el transmisor pase lo que pase.
   *
   * Se llama al salir: dejar la portadora encendida deja el canal mudo para
   * todos los equipos del evento, no solo para el puente.
   */
  async release() {
    if (this.mode === PttMode.vox) return;
    this.isKeyed = true;
    await this.setKeyed(false);
  }
}
