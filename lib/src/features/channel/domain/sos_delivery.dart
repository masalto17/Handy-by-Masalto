import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';

/// Que se le puede decir honestamente al operador despues de mandar un SOS.
enum SosDeliveryOutcome {
  /// Se registro, pero no se puede saber quien estaba conectado (modo demo,
  /// o la sala del canal no esta conectada en este dispositivo).
  recorded,

  /// Habia otros operadores conectados al canal en ese momento.
  reachedOthers,

  /// Se registro y **no habia nadie mas conectado** al canal.
  ///
  /// Es el caso critico: sin este aviso, el operador supone que viene
  /// ayuda cuando en realidad su SOS no lo escucho nadie en vivo.
  nobodyConnected,
}

/// Resultado de un SOS: que paso y a cuantos alcanzo.
class SosDelivery {
  /// Crea el resultado.
  const SosDelivery({required this.outcome, this.otherParticipants = 0});

  /// Que se puede afirmar sobre la entrega.
  final SosDeliveryOutcome outcome;

  /// Operadores conectados al canal ademas de quien envio.
  final int otherParticipants;

  /// Decide el resultado a partir del modo de audio y la presencia del canal.
  ///
  /// Solo se afirma algo sobre la entrega cuando el audio es real y la sala
  /// esta conectada: en cualquier otro caso se dice unicamente que quedo
  /// registrado, para no dar una falsa sensacion de cobertura.
  static SosDelivery evaluate({
    required AudioMode mode,
    required ChannelPresence? presence,
  }) {
    if (!mode.transmits || presence == null || !presence.isConnected) {
      return const SosDelivery(outcome: SosDeliveryOutcome.recorded);
    }
    // participantCount incluye a quien envia.
    final others = presence.participantCount - 1;
    if (others <= 0) {
      return const SosDelivery(outcome: SosDeliveryOutcome.nobodyConnected);
    }
    return SosDelivery(
      outcome: SosDeliveryOutcome.reachedOthers,
      otherParticipants: others,
    );
  }
}
