import 'dart:async';
import 'dart:typed_data';

import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de entrega de un mensaje PTT que ya se transmitio en vivo pero
/// todavia no quedo guardado en el backend.
enum PttDeliveryStatus {
  /// Esperando su turno para (re)intentar el envio.
  pending,

  /// Envio en curso.
  sending,

  /// Se agotaron los reintentos automaticos. Queda a la espera de un
  /// reintento manual; nunca se descarta solo.
  failed,
}

/// Un mensaje PTT pendiente de guardarse.
///
/// El audio en vivo ya salio por LiveKit: lo que esta pendiente es dejarlo
/// asentado en el historial. Se conserva en memoria hasta confirmarlo para
/// que un corte de red al soltar el boton no se coma el mensaje.
class PendingPttMessage {
  /// Crea un pendiente. [id] debe ser unico dentro de la cola.
  const PendingPttMessage({
    required this.id,
    required this.session,
    required this.channels,
    required this.durationSeconds,
    required this.createdAt,
    this.audioBytes,
    this.audioMimeType,
    this.browserTranscriptionText,
    this.attempts = 0,
    this.status = PttDeliveryStatus.pending,
  });

  /// Identificador local del pendiente.
  final String id;

  /// Sesion con la que se transmitio.
  final EventSession session;

  /// Canales a los que iba dirigido.
  final List<EventChannel> channels;

  /// Duracion de la transmision, en segundos.
  final int durationSeconds;

  /// Momento en que se encolo.
  final DateTime createdAt;

  /// Audio grabado localmente, si la grabacion funciono.
  final Uint8List? audioBytes;

  /// Tipo MIME del audio grabado.
  final String? audioMimeType;

  /// Transcripcion del navegador, si estuvo disponible.
  final String? browserTranscriptionText;

  /// Intentos de envio ya realizados.
  final int attempts;

  /// Estado actual de entrega.
  final PttDeliveryStatus status;

  /// `true` si el pendiente lleva audio grabado.
  bool get hasAudio => audioBytes != null && audioBytes!.isNotEmpty;

  PendingPttMessage copyWith({
    int? attempts,
    PttDeliveryStatus? status,
  }) {
    return PendingPttMessage(
      id: id,
      session: session,
      channels: channels,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      audioBytes: audioBytes,
      audioMimeType: audioMimeType,
      browserTranscriptionText: browserTranscriptionText,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
    );
  }
}

/// Resultado de un envio exitoso, para que la UI pueda refrescar historial.
class PttDelivered {
  const PttDelivered({required this.pending, required this.messages});

  /// El pendiente que se logro entregar.
  final PendingPttMessage pending;

  /// Mensajes de voz creados en el backend.
  final List<VoiceMessage> messages;
}

/// Cola de reenvio de mensajes PTT.
///
/// Un `handy` no puede perder un mensaje porque se cayo la red justo al
/// soltar el boton. Esta cola guarda el mensaje ya grabado y lo reintenta
/// con backoff exponencial; si agota los reintentos automaticos lo deja en
/// [PttDeliveryStatus.failed] a la espera de un reintento manual, pero
/// **nunca lo descarta en silencio**.
///
/// Limitacion conocida: la cola vive en memoria, asi que sobrevive a cortes
/// de red pero no a que el sistema mate la app. Persistirla en disco es el
/// siguiente paso.
class PttOutbox extends StateNotifier<List<PendingPttMessage>> {
  /// Crea la cola con el repositorio inyectado.
  ///
  /// [backoff] permite acortar las esperas en tests; en produccion usa
  /// [defaultBackoffFor].
  PttOutbox(
    this._repository, {
    Duration Function(int attempt)? backoff,
  })  : _backoff = backoff ?? defaultBackoffFor,
        super(const []);

  /// Intentos automaticos antes de pasar a [PttDeliveryStatus.failed].
  static const int maxAutoAttempts = 4;

  final EventRadioRepository _repository;
  final Duration Function(int attempt) _backoff;

  final StreamController<PttDelivered> _deliveredController =
      StreamController<PttDelivered>.broadcast();

  var _nextId = 0;
  bool _isDraining = false;

  /// Emite cada vez que un pendiente se entrega, para refrescar el historial.
  Stream<PttDelivered> get delivered => _deliveredController.stream;

  /// Pendientes que todavia pueden entregarse solos.
  int get pendingCount => state
      .where((message) => message.status != PttDeliveryStatus.failed)
      .length;

  /// Pendientes que agotaron los reintentos automaticos.
  int get failedCount => state
      .where((message) => message.status == PttDeliveryStatus.failed)
      .length;

  /// Calcula la espera antes del intento numero [attempt] (1-based).
  ///
  /// Backoff exponencial 2s, 4s, 8s... con techo de 30s para que un evento
  /// largo no quede esperando minutos entre reintentos.
  static Duration defaultBackoffFor(int attempt) {
    final seconds = 1 << attempt.clamp(1, 5);
    return Duration(seconds: seconds > 30 ? 30 : seconds);
  }

  /// Encola un mensaje ya transmitido para guardarlo, e inicia el drenado.
  ///
  /// Devuelve el pendiente creado.
  PendingPttMessage enqueue({
    required EventSession session,
    required List<EventChannel> channels,
    required int durationSeconds,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? browserTranscriptionText,
    DateTime? createdAt,
  }) {
    final pending = PendingPttMessage(
      id: 'ptt-${_nextId++}',
      session: session,
      channels: channels,
      durationSeconds: durationSeconds,
      createdAt: createdAt ?? DateTime.now(),
      audioBytes: audioBytes,
      audioMimeType: audioMimeType,
      browserTranscriptionText: browserTranscriptionText,
    );
    state = [...state, pending];
    unawaited(_drain());
    return pending;
  }

  /// Vuelve a marcar como pendientes los mensajes fallidos y reintenta.
  Future<void> retryFailed() async {
    state = [
      for (final message in state)
        message.status == PttDeliveryStatus.failed
            ? message.copyWith(status: PttDeliveryStatus.pending, attempts: 0)
            : message,
    ];
    await _drain();
  }

  /// Descarta un pendiente por decision explicita del operador.
  void discard(String id) {
    state = state.where((message) => message.id != id).toList();
  }

  /// Procesa la cola de a un mensaje por vez, respetando el orden en que se
  /// hablo. Es reentrante: si ya hay un drenado en curso, no arranca otro.
  Future<void> _drain() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      while (true) {
        final next = state
            .where((message) => message.status == PttDeliveryStatus.pending)
            .firstOrNull;
        if (next == null) return;

        if (next.attempts > 0) {
          await Future<void>.delayed(_backoff(next.attempts));
          if (!mounted) return;
        }

        _update(next.id, (message) => message.copyWith(
              status: PttDeliveryStatus.sending,
            ));

        try {
          final messages = await _repository.sendPttMessage(
            session: next.session,
            channels: next.channels,
            durationSeconds: next.durationSeconds,
            audioBytes: next.audioBytes,
            audioMimeType: next.audioMimeType,
            browserTranscriptionText: next.browserTranscriptionText,
          );
          if (!mounted) return;
          state = state.where((message) => message.id != next.id).toList();
          _deliveredController.add(
            PttDelivered(pending: next, messages: messages),
          );
        } catch (_) {
          if (!mounted) return;
          final attempts = next.attempts + 1;
          _update(
            next.id,
            (message) => message.copyWith(
              attempts: attempts,
              status: attempts >= maxAutoAttempts
                  ? PttDeliveryStatus.failed
                  : PttDeliveryStatus.pending,
            ),
          );
        }
      }
    } finally {
      _isDraining = false;
    }
  }

  void _update(
    String id,
    PendingPttMessage Function(PendingPttMessage) transform,
  ) {
    state = [
      for (final message in state)
        message.id == id ? transform(message) : message,
    ];
  }

  @override
  void dispose() {
    unawaited(_deliveredController.close());
    super.dispose();
  }
}

/// Cola de reenvio de mensajes PTT de la sesion activa.
final pttOutboxProvider =
    StateNotifierProvider<PttOutbox, List<PendingPttMessage>>((ref) {
  return PttOutbox(ref.watch(eventRadioRepositoryProvider));
});

/// Refresca historial y bitacora cuando un pendiente se entrega tarde.
///
/// Sin esto, un mensaje reenviado con exito no apareceria en el historial
/// hasta que el operador recargue a mano.
final pttOutboxSyncProvider = Provider<void>((ref) {
  final subscription =
      ref.watch(pttOutboxProvider.notifier).delivered.listen((delivered) {
    for (final channel in delivered.pending.channels) {
      ref.invalidate(voiceMessagesProvider(channel.id));
    }
    ref.invalidate(eventLogsProvider(delivered.pending.session.event.id));
  });
  ref.onDispose(subscription.cancel);
});
