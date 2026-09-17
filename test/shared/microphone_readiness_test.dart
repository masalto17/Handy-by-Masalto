import 'package:event_radio_app/src/shared/audio/microphone_readiness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('readinessFor', () {
    test('granted and limited count as ready', () {
      expect(
        MicrophoneReadinessController.readinessFor(PermissionStatus.granted),
        MicrophoneReadiness.ready,
      );
      // iOS puede dar acceso limitado: alcanza para transmitir.
      expect(
        MicrophoneReadinessController.readinessFor(PermissionStatus.limited),
        MicrophoneReadiness.ready,
      );
    });

    test('permanently denied and restricted need system settings', () {
      // En estos casos la app ya no puede volver a preguntar: el operador
      // tiene que ir a los ajustes, y hay que decirselo.
      expect(
        MicrophoneReadinessController.readinessFor(
          PermissionStatus.permanentlyDenied,
        ),
        MicrophoneReadiness.blocked,
      );
      expect(
        MicrophoneReadinessController.readinessFor(PermissionStatus.restricted),
        MicrophoneReadiness.blocked,
      );
    });

    test('denied can still be requested from the app', () {
      expect(
        MicrophoneReadinessController.readinessFor(PermissionStatus.denied),
        MicrophoneReadiness.needsGrant,
      );
    });
  });

  group('needsAttention', () {
    test('flags only the states the operator must act on', () {
      expect(MicrophoneReadiness.needsGrant.needsAttention, isTrue);
      expect(MicrophoneReadiness.blocked.needsAttention, isTrue);
      expect(MicrophoneReadiness.ready.needsAttention, isFalse);
      // unknown no molesta al operador: el flujo del PTT lo resuelve.
      expect(MicrophoneReadiness.unknown.needsAttention, isFalse);
    });
  });

  group('refresh', () {
    test('reports ready when the permission is granted', () async {
      final controller = MicrophoneReadinessController(
        checkStatus: () async => PermissionStatus.granted,
        isWeb: false,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.state, MicrophoneReadiness.ready);
    });

    test('stays unknown on web instead of prompting', () async {
      var checked = false;
      final controller = MicrophoneReadinessController(
        checkStatus: () async {
          checked = true;
          return PermissionStatus.denied;
        },
        isWeb: true,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      // No se consulta: en el navegador el prompt lo dispara el uso real.
      expect(checked, isFalse);
      expect(controller.state, MicrophoneReadiness.unknown);
    });

    test('falls back to unknown when the platform throws', () async {
      final controller = MicrophoneReadinessController(
        checkStatus: () async => throw Exception('unsupported'),
        isWeb: false,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      // Un plugin sin soporte no debe bloquear la pantalla de canal.
      expect(controller.state, MicrophoneReadiness.unknown);
    });
  });

  group('request', () {
    test('updates state from the permission result', () async {
      final controller = MicrophoneReadinessController(
        checkStatus: () async => PermissionStatus.denied,
        requestPermission: () async => PermissionStatus.granted,
        isWeb: false,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.state, MicrophoneReadiness.needsGrant);

      await controller.request();
      expect(controller.state, MicrophoneReadiness.ready);
    });

    test('reflects a permanent denial so the card offers settings', () async {
      final controller = MicrophoneReadinessController(
        requestPermission: () async => PermissionStatus.permanentlyDenied,
        isWeb: false,
      );
      addTearDown(controller.dispose);

      await controller.request();
      expect(controller.state, MicrophoneReadiness.blocked);
    });
  });
}
