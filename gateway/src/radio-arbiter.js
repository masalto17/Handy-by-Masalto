/**
 * Arbitraje half-duplex entre la sala y el handy UHF.
 *
 * Un handy no es full duplex: mientras transmite, su receptor esta sordo, y
 * si dos equipos transmiten a la vez en la misma frecuencia se tapan. El
 * puente tiene entonces que decidir, en cada momento, quien tiene el canal:
 * la sala (celulares) o el aire (handies).
 *
 * Todo el tiempo aparece como parametro: la clase no mira el reloj, asi que
 * se puede testear sin esperar.
 */

/** Estados del puente. */
export const ArbiterState = {
  /** Nadie tiene el canal. */
  idle: 'idle',
  /** Transmisor encendido, todavia sin mandar audio (cola de apertura). */
  keying: 'keying',
  /** Transmitiendo audio de la sala al aire. */
  keyed: 'keyed',
  /** La sala dejo de hablar; se sostiene la portadora un instante. */
  tail: 'tail',
  /** Un handy tiene el canal: su audio va a la sala. */
  receiving: 'receiving',
  /** Transmision cortada por exceder el tiempo maximo. */
  lockout: 'lockout',
};

/**
 * Maquina de estados del puente.
 */
export class RadioArbiter {
  /**
   * @param {object} options
   * @param {number} options.leadMs Espera entre encender el transmisor y
   *   empezar a mandar audio. Sin esto se pierde la primera silaba: el
   *   transmisor tarda en levantar y los handies del otro lado tardan en
   *   abrir el squelch.
   * @param {number} options.tailMs Cuanto se sostiene la portadora despues
   *   de la ultima palabra, para no cortarla.
   * @param {number} options.maxKeyMs Tiempo maximo de transmision continua.
   *   Los equipos reales tienen este limite ("time-out timer"): una
   *   transmision trabada recalienta la etapa final y deja el canal mudo
   *   para todos los demas.
   * @param {number} options.lockoutMs Espera obligatoria despues de un corte
   *   por tiempo maximo, para no volver a tomar el canal en el acto.
   */
  constructor({ leadMs, tailMs, maxKeyMs, lockoutMs }) {
    for (const [name, value] of Object.entries({
      leadMs,
      tailMs,
      maxKeyMs,
      lockoutMs,
    })) {
      if (!(value >= 0)) throw new Error(`${name} no puede ser negativo.`);
    }
    if (!(maxKeyMs > leadMs)) {
      throw new Error('maxKeyMs tiene que superar a leadMs.');
    }
    this.leadMs = leadMs;
    this.tailMs = tailMs;
    this.maxKeyMs = maxKeyMs;
    this.lockoutMs = lockoutMs;

    this.state = ArbiterState.idle;
    this._keyedAt = 0;
    this._lastRoomAudioAt = 0;
    this._lockoutUntil = 0;
    /** Cuantas veces se corto por tiempo maximo, para diagnostico. */
    this.timeouts = 0;
  }

  /**
   * Avanza la maquina un paso.
   *
   * @param {object} input
   * @param {boolean} input.roomActive Hay alguien hablando en la sala.
   * @param {boolean} input.radioActive El squelch del receptor esta abierto.
   * @param {number} input.nowMs Reloj monotono en ms.
   * @returns {{state: string, keyed: boolean, sendAudioToRadio: boolean,
   *   publishRadioAudio: boolean}}
   */
  update({ roomActive, radioActive, nowMs }) {
    switch (this.state) {
      case ArbiterState.lockout:
        if (nowMs >= this._lockoutUntil) this.state = ArbiterState.idle;
        break;

      case ArbiterState.receiving:
        // El aire tiene prioridad mientras dure: cortarlo a la mitad para
        // que hable la sala es exactamente lo que no se puede hacer.
        if (!radioActive) this.state = ArbiterState.idle;
        break;

      case ArbiterState.idle:
        break;

      case ArbiterState.keying:
      case ArbiterState.keyed:
      case ArbiterState.tail:
        this._advanceTransmitting({ roomActive, nowMs });
        break;

      /* c8 ignore next 2 */
      default:
        throw new Error(`Estado desconocido: ${this.state}`);
    }

    // Arranque de una transmision nueva, ya resuelto el estado anterior.
    if (this.state === ArbiterState.idle) {
      if (radioActive) {
        this.state = ArbiterState.receiving;
      } else if (roomActive) {
        this.state = ArbiterState.keying;
        this._keyedAt = nowMs;
        this._lastRoomAudioAt = nowMs;
      }
    }

    return this.snapshot();
  }

  _advanceTransmitting({ roomActive, nowMs }) {
    if (nowMs - this._keyedAt >= this.maxKeyMs) {
      this.timeouts += 1;
      this.state = ArbiterState.lockout;
      this._lockoutUntil = nowMs + this.lockoutMs;
      return;
    }

    if (roomActive) {
      this._lastRoomAudioAt = nowMs;
      this.state =
        nowMs - this._keyedAt >= this.leadMs
          ? ArbiterState.keyed
          : ArbiterState.keying;
      return;
    }

    if (nowMs - this._lastRoomAudioAt >= this.tailMs) {
      this.state = ArbiterState.idle;
      return;
    }
    this.state = ArbiterState.tail;
  }

  /** Decisiones que corresponden al estado actual. */
  snapshot() {
    const keyed =
      this.state === ArbiterState.keying ||
      this.state === ArbiterState.keyed ||
      this.state === ArbiterState.tail;
    return {
      state: this.state,
      keyed,
      // Durante la cola de apertura el transmisor ya esta encendido pero
      // todavia no levanto: mandar audio ahi es perderlo.
      sendAudioToRadio: this.state === ArbiterState.keyed,
      // Nunca se publica con el transmisor encendido: seria realimentacion.
      publishRadioAudio: this.state === ArbiterState.receiving,
    };
  }
}
