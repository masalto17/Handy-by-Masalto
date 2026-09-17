import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioMode', () {
    test('only live mode actually transmits', () {
      expect(AudioMode.live.transmits, isTrue);
      // Estos dos NO transmiten: el mock simula el ciclo PTT sin mandar
      // audio a nadie, y la UI tiene que decirlo en vez de aparentar exito.
      expect(AudioMode.simulated.transmits, isFalse);
      expect(AudioMode.unavailable.transmits, isFalse);
    });

    test('unavailable is distinct from simulated', () {
      // simulated es esperado en una demo; unavailable es una instalacion
      // real mal configurada, y merece un aviso mucho mas fuerte.
      expect(AudioMode.simulated, isNot(AudioMode.unavailable));
    });
  });
}
