/**
 * Nivel de audio y squelch.
 *
 * El radio entrega audio siempre: cuando nadie habla, entrega ruido de
 * fondo. Si se publicara tal cual, la sala escucharia hiss permanente y el
 * ducking de emergencia se dispararia solo. Por eso hace falta decidir
 * cuando hay voz de verdad.
 */

/**
 * RMS de un bloque PCM16, normalizado a 0..1.
 *
 * @param {Int16Array} samples
 * @returns {number}
 */
export function rms(samples) {
  if (samples.length === 0) return 0;
  let sum = 0;
  for (let i = 0; i < samples.length; i += 1) {
    const value = samples[i] / 32768;
    sum += value * value;
  }
  return Math.sqrt(sum / samples.length);
}

/**
 * Puerta de squelch con histeresis y tiempo de cola.
 *
 * Dos umbrales en vez de uno: con uno solo, una voz que roza el umbral
 * abre y cierra decenas de veces por segundo y corta silabas. El tiempo de
 * cola (`hangMs`) mantiene abierto durante las pausas naturales del habla,
 * que son mas largas que un bloque de audio.
 */
export class SquelchGate {
  /**
   * @param {object} options
   * @param {number} options.openLevel Nivel RMS que abre la puerta.
   * @param {number} [options.closeLevel] Nivel para cerrar; por defecto, la
   *   mitad del de apertura.
   * @param {number} options.hangMs Cuanto sigue abierta tras caer el nivel.
   */
  constructor({ openLevel, closeLevel, hangMs }) {
    if (!(openLevel > 0)) {
      throw new Error('openLevel tiene que ser mayor que cero.');
    }
    if (!(hangMs >= 0)) {
      throw new Error('hangMs no puede ser negativo.');
    }
    this.openLevel = openLevel;
    this.closeLevel = closeLevel ?? openLevel / 2;
    if (this.closeLevel > this.openLevel) {
      throw new Error('closeLevel no puede superar a openLevel.');
    }
    this.hangMs = hangMs;
    this.isOpen = false;
    this._lastAboveAt = 0;
  }

  /**
   * Alimenta un bloque y devuelve si la puerta quedo abierta.
   *
   * @param {number} level RMS del bloque (0..1).
   * @param {number} nowMs Reloj monotono en ms.
   * @returns {boolean}
   */
  update(level, nowMs) {
    if (level >= this.openLevel) {
      this._lastAboveAt = nowMs;
      this.isOpen = true;
      return true;
    }

    if (!this.isOpen) return false;

    // Entre closeLevel y openLevel se sostiene: es la histeresis, y evita
    // el castañeteo en el borde del umbral.
    if (level >= this.closeLevel) {
      this._lastAboveAt = nowMs;
      return true;
    }

    if (nowMs - this._lastAboveAt >= this.hangMs) {
      this.isOpen = false;
      return false;
    }
    return true;
  }
}
