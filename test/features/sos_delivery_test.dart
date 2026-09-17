import 'package:event_radio_app/src/features/channel/domain/sos_delivery.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:flutter_test/flutter_test.dart';

ChannelPresence _presence({
  required int participantCount,
  bool isConnected = true,
}) {
  return ChannelPresence(
    channelId: 'ch-1',
    channelName: 'Seguridad',
    isEmergency: true,
    isConnected: isConnected,
    participantCount: participantCount,
    speakingNames: const [],
  );
}

void main() {
  group('SosDelivery.evaluate', () {
    test('warns when nobody else is connected', () {
      // El caso critico: sin este aviso el operador supone que viene ayuda.
      final delivery = SosDelivery.evaluate(
        mode: AudioMode.live,
        presence: _presence(participantCount: 1), // solo quien envia
      );
      expect(delivery.outcome, SosDeliveryOutcome.nobodyConnected);
    });

    test('reports how many others were connected', () {
      final delivery = SosDelivery.evaluate(
        mode: AudioMode.live,
        presence: _presence(participantCount: 4),
      );
      expect(delivery.outcome, SosDeliveryOutcome.reachedOthers);
      // participantCount incluye a quien envia: 4 en la sala = 3 otros.
      expect(delivery.otherParticipants, 3);
    });

    test('only says "recorded" when audio is not real', () {
      // En demo la presencia esta vacia; afirmar que no hay nadie seria
      // alarmar por un dato que no significa lo que parece.
      for (final mode in [AudioMode.simulated, AudioMode.unavailable]) {
        final delivery = SosDelivery.evaluate(
          mode: mode,
          presence: _presence(participantCount: 1),
        );
        expect(delivery.outcome, SosDeliveryOutcome.recorded);
      }
    });

    test('only says "recorded" when presence is unknown', () {
      expect(
        SosDelivery.evaluate(mode: AudioMode.live, presence: null).outcome,
        SosDeliveryOutcome.recorded,
      );
    });

    test('only says "recorded" when the room is not connected', () {
      // Sin sala conectada el contador no es informacion confiable.
      final delivery = SosDelivery.evaluate(
        mode: AudioMode.live,
        presence: _presence(participantCount: 5, isConnected: false),
      );
      expect(delivery.outcome, SosDeliveryOutcome.recorded);
    });

    test('treats an inconsistent count as nobody connected', () {
      // Defensivo: un contador en 0 no debe leerse como "-1 otros".
      final delivery = SosDelivery.evaluate(
        mode: AudioMode.live,
        presence: _presence(participantCount: 0),
      );
      expect(delivery.outcome, SosDeliveryOutcome.nobodyConnected);
      expect(delivery.otherParticipants, 0);
    });
  });
}
