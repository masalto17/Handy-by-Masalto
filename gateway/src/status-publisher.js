/**
 * Informa a la sala que esta haciendo el puente.
 *
 * El operador necesita ver en la app si el enlace con los handies esta
 * arriba y si algo se corto: sin eso, un puente caido se parece demasiado a
 * un canal tranquilo.
 *
 * Viaja por atributos de LiveKit y no por el backend a proposito: asi el
 * estado llega exactamente cuando llega el audio, incluso con el servidor
 * local del predio y sin internet.
 */

/** Clave del atributo con el estado del puente. */
export const STATE_ATTRIBUTE = 'bridge_state';

/** Clave del atributo con la cuenta de cortes por tiempo maximo. */
export const TIMEOUTS_ATTRIBUTE = 'bridge_timeouts';

export class StatusPublisher {
  /**
   * @param {object} options
   * @param {(attributes: Record<string, string>) => Promise<unknown>}
   *   options.publish Normalmente `localParticipant.setAttributes`.
   * @param {(message: string, error?: unknown) => void} [options.onError]
   */
  constructor({ publish, onError }) {
    this._publish = publish;
    this._onError = onError ?? (() => {});
    this._lastSent = null;
    /** Un solo carril: dos envios en paralelo pueden llegar al reves y
     * dejar publicado un estado viejo. */
    this._queue = Promise.resolve();
  }

  /**
   * Publica el estado si cambio respecto del ultimo enviado.
   *
   * El puente cambia de estado varias veces por segundo; reenviar lo mismo
   * seria trafico constante en una red que puede ser la del predio.
   *
   * @param {object} status
   * @param {string} status.state
   * @param {number} status.timeouts
   * @returns {Promise<void>}
   */
  async update({ state, timeouts }) {
    const attributes = {
      [STATE_ATTRIBUTE]: state,
      [TIMEOUTS_ATTRIBUTE]: String(timeouts),
    };
    const serialized = JSON.stringify(attributes);
    if (serialized === this._lastSent) return;
    this._lastSent = serialized;

    this._queue = this._queue.then(async () => {
      try {
        await this._publish(attributes);
      } catch (error) {
        // Que no se pueda informar el estado no es razon para cortar el
        // audio: el puente sigue andando, mudo para la app.
        this._lastSent = null;
        this._onError('No se pudo publicar el estado del puente.', error);
      }
    });
    return this._queue;
  }
}
