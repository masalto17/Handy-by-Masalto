/// Estados explícitos del ciclo Push-to-Talk.
///
/// Reemplaza los flags booleanos (`_isTransmitting`, `_isSaving`) con una
/// maquina de estados que impide transiciones invalidas y da a la UI un
/// estado inequivoco para cada momento del ciclo.
enum PttPhase {
  /// Listo para transmitir.
  idle,

  /// El usuario presiono el boton; se estan negociando permisos de microfono
  /// y la conexion a la sala LiveKit. Aun no hay audio saliente.
  requesting,

  /// La sala esta confirmada y el microfono esta publicando audio.
  transmitting,

  /// El usuario solto el boton; se estan guardando grabacion, transcripcion
  /// e historial.
  finalizing,

  /// Error durante la fase requesting: permiso denegado o sala no disponible.
  error,
}

class PttState {
  const PttState({
    this.phase = PttPhase.idle,
    this.elapsedSeconds = 0,
    this.errorMessage,
  });

  final PttPhase phase;
  final int elapsedSeconds;
  final String? errorMessage;

  bool get isIdle => phase == PttPhase.idle;
  bool get isRequesting => phase == PttPhase.requesting;
  bool get isTransmitting => phase == PttPhase.transmitting;
  bool get isFinalizing => phase == PttPhase.finalizing;
  bool get isError => phase == PttPhase.error;

  /// El boton esta activo (el usuario lo mantiene presionado).
  bool get isActive =>
      phase == PttPhase.requesting || phase == PttPhase.transmitting;

  /// La UI no debe aceptar un nuevo press.
  bool get isBusy => !isIdle && !isError;

  PttState copyWith({
    PttPhase? phase,
    int? elapsedSeconds,
    String? errorMessage,
  }) {
    return PttState(
      phase: phase ?? this.phase,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      errorMessage: errorMessage,
    );
  }

  static const idle = PttState();
}
