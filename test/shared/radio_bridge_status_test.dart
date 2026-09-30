import 'dart:convert';

import 'package:event_radio_app/src/shared/audio/radio_bridge_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metadata tal como la firma la edge function `livekit-token`.
String _metadata(String role) => jsonEncode({
      'event_id': 'e1',
      'channel_id': 'c1',
      'role': role,
    });

RadioBridgeStatus? parse({
  String name = 'Radio UHF',
  String? metadata,
  Map<String, String> attributes = const {},
}) {
  return RadioBridgeStatus.fromParticipant(
    name: name,
    metadata: metadata ?? _metadata('gateway'),
    attributes: attributes,
  );
}

void main() {
  group('fromParticipant', () {
    test('reconoce un puente por su rol firmado', () {
      final status = parse(attributes: {'bridge_state': 'idle'});
      expect(status, isNotNull);
      expect(status!.name, 'Radio UHF');
      expect(status.state, RadioBridgeState.idle);
    });

    test('un participante comun no es un puente', () {
      // Aunque publique los mismos atributos: el rol lo pone el servidor.
      final status = parse(
        metadata: _metadata('participant'),
        attributes: {'bridge_state': 'keyed'},
      );
      expect(status, isNull);
    });

    test('sin metadata no es un puente', () {
      expect(parse(metadata: ''), isNull);
    });

    test('metadata que no es JSON no rompe la pantalla', () {
      expect(parse(metadata: 'no-soy-json'), isNull);
    });

    test('metadata JSON sin rol no es un puente', () {
      expect(parse(metadata: jsonEncode({'event_id': 'e1'})), isNull);
    });

    test('metadata que es un JSON no-objeto no es un puente', () {
      expect(parse(metadata: jsonEncode([1, 2, 3])), isNull);
    });
  });

  group('estado', () {
    test('las tres fases de transmision se ven como una sola', () {
      // El puente distingue encendido, audio y cola; para el operador es
      // un solo hecho: esta al aire.
      for (final raw in ['keying', 'keyed', 'tail']) {
        expect(
          parse(attributes: {'bridge_state': raw})!.state,
          RadioBridgeState.transmitting,
          reason: raw,
        );
      }
    });

    test('receiving y lockout se mapean directo', () {
      expect(
        parse(attributes: {'bridge_state': 'receiving'})!.state,
        RadioBridgeState.receiving,
      );
      expect(
        parse(attributes: {'bridge_state': 'lockout'})!.state,
        RadioBridgeState.lockout,
      );
    });

    test('un puente presente que todavia no informo queda en unknown', () {
      // Es distinto de "no hay puente": esta en el canal, arrancando.
      expect(parse()!.state, RadioBridgeState.unknown);
    });

    test('un estado desconocido no se interpreta como funcionando', () {
      expect(
        parse(attributes: {'bridge_state': 'inventado'})!.state,
        RadioBridgeState.unknown,
      );
    });

    test('solo el corte por tiempo maximo pide atencion', () {
      expect(RadioBridgeState.lockout.needsAttention, isTrue);
      for (final state in RadioBridgeState.values) {
        if (state == RadioBridgeState.lockout) continue;
        expect(state.needsAttention, isFalse, reason: '$state');
      }
    });

    test('solo receiving y transmitting pasan audio', () {
      expect(RadioBridgeState.receiving.isPassingAudio, isTrue);
      expect(RadioBridgeState.transmitting.isPassingAudio, isTrue);
      expect(RadioBridgeState.idle.isPassingAudio, isFalse);
      expect(RadioBridgeState.lockout.isPassingAudio, isFalse);
      expect(RadioBridgeState.unknown.isPassingAudio, isFalse);
    });
  });

  group('cortes por tiempo maximo', () {
    test('se leen del atributo', () {
      expect(parse(attributes: {'bridge_timeouts': '3'})!.timeouts, 3);
    });

    test('un valor corrupto no rompe la pantalla', () {
      expect(parse(attributes: {'bridge_timeouts': 'muchos'})!.timeouts, 0);
    });

    test('sin atributo, cero', () {
      expect(parse()!.timeouts, 0);
    });
  });

  test('usa la identidad cuando el participante no tiene nombre', () {
    final status = RadioBridgeStatus.fromParticipant(
      name: 'participant-123',
      metadata: _metadata('gateway'),
      attributes: const {},
    );
    expect(status!.name, 'participant-123');
  });
}
