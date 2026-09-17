import 'dart:typed_data';

import 'package:event_radio_app/src/shared/audio/ptt_outbox.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/data/mock_event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio que falla las primeras [failuresBeforeSuccess] veces.
///
/// Permite simular un corte de red al soltar el boton y verificar que el
/// mensaje no se pierde.
class _FlakyRepository extends MockEventRadioRepository {
  _FlakyRepository({required this.failuresBeforeSuccess});

  int failuresBeforeSuccess;
  int attempts = 0;

  @override
  Future<List<VoiceMessage>> sendPttMessage({
    required EventSession session,
    required List<EventChannel> channels,
    required int durationSeconds,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? browserTranscriptionText,
  }) async {
    attempts++;
    if (attempts <= failuresBeforeSuccess) {
      throw Exception('network down');
    }
    return super.sendPttMessage(
      session: session,
      channels: channels,
      durationSeconds: durationSeconds,
      audioBytes: audioBytes,
      audioMimeType: audioMimeType,
      browserTranscriptionText: browserTranscriptionText,
    );
  }
}

Future<EventSession> _session(EventRadioRepository repository) {
  return repository.joinByCode('SATI26');
}

/// Backoff casi instantaneo: los tests verifican la logica de reintento,
/// no la duracion real de las esperas.
Duration _fastBackoff(int attempt) => const Duration(milliseconds: 5);

void main() {
  group('backoffFor', () {
    test('grows exponentially and caps at 30s', () {
      expect(PttOutbox.defaultBackoffFor(1), const Duration(seconds: 2));
      expect(PttOutbox.defaultBackoffFor(2), const Duration(seconds: 4));
      expect(PttOutbox.defaultBackoffFor(3), const Duration(seconds: 8));
      expect(PttOutbox.defaultBackoffFor(10), const Duration(seconds: 30));
    });
  });

  test('delivers straight away when the backend is healthy', () async {
    final repository = MockEventRadioRepository();
    final session = await _session(repository);
    final outbox = PttOutbox(repository, backoff: _fastBackoff);
    addTearDown(outbox.dispose);

    final delivered = outbox.delivered.first;
    outbox.enqueue(
      session: session,
      channels: [session.orderedChannels.first],
      durationSeconds: 3,
    );

    await delivered;
    expect(outbox.state, isEmpty);
  });

  test('keeps the message queued when the send fails', () async {
    final repository = _FlakyRepository(failuresBeforeSuccess: 1);
    final session = await _session(repository);
    final outbox = PttOutbox(repository, backoff: _fastBackoff);
    addTearDown(outbox.dispose);

    final delivered = outbox.delivered.first;
    outbox.enqueue(
      session: session,
      channels: [session.orderedChannels.first],
      durationSeconds: 3,
      audioBytes: Uint8List.fromList([1, 2, 3]),
      audioMimeType: 'audio/wav',
    );

    // Tras el primer fallo el mensaje sigue en la cola, no se descarta.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(outbox.state, hasLength(1));
    expect(outbox.state.single.attempts, 1);

    // Y el reintento automatico termina entregandolo, con el audio intacto.
    final result = await delivered;
    expect(result.pending.hasAudio, isTrue);
    expect(outbox.state, isEmpty);
    expect(repository.attempts, 2);
  });

  test('marks as failed after exhausting automatic attempts', () async {
    final repository = _FlakyRepository(failuresBeforeSuccess: 999);
    final session = await _session(repository);
    final outbox = PttOutbox(repository, backoff: _fastBackoff);
    addTearDown(outbox.dispose);

    outbox.enqueue(
      session: session,
      channels: [session.orderedChannels.first],
      durationSeconds: 3,
    );

    // Con _fastBackoff los 4 intentos automaticos ocurren en ~30ms.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(repository.attempts, PttOutbox.maxAutoAttempts);
    // Nunca se descarta solo: queda para reintento manual.
    expect(outbox.state, hasLength(1));
    expect(outbox.state.single.status, PttDeliveryStatus.failed);
    expect(outbox.failedCount, 1);
  });

  test('retryFailed sends again once the network recovers', () async {
    final repository = _FlakyRepository(failuresBeforeSuccess: 999);
    final session = await _session(repository);
    final outbox = PttOutbox(repository, backoff: _fastBackoff);
    addTearDown(outbox.dispose);

    outbox.enqueue(
      session: session,
      channels: [session.orderedChannels.first],
      durationSeconds: 3,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(outbox.state.single.status, PttDeliveryStatus.failed);

    // Vuelve la red.
    repository.failuresBeforeSuccess = 0;
    final delivered = outbox.delivered.first;
    await outbox.retryFailed();
    await delivered;

    expect(outbox.state, isEmpty);
  });

  test('discard removes a message only when asked explicitly', () async {
    final repository = _FlakyRepository(failuresBeforeSuccess: 999);
    final session = await _session(repository);
    final outbox = PttOutbox(repository, backoff: _fastBackoff);
    addTearDown(outbox.dispose);

    final pending = outbox.enqueue(
      session: session,
      channels: [session.orderedChannels.first],
      durationSeconds: 3,
    );
    outbox.discard(pending.id);

    expect(outbox.state, isEmpty);
  });
}
