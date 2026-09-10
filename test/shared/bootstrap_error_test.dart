import 'package:event_radio_app/src/core/config/app_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BootstrapError', () {
    test('toString with detail includes both parts', () {
      const error = BootstrapError(
        message: 'No se pudo conectar con Supabase.',
        detail: 'SocketException: Connection refused',
      );
      expect(error.toString(),
          'No se pudo conectar con Supabase. (SocketException: Connection refused)');
    });

    test('toString without detail shows only message', () {
      const error = BootstrapError(
        message: 'Configuracion de Supabase ausente.',
      );
      expect(error.toString(), 'Configuracion de Supabase ausente.');
    });

    test('detail defaults to null', () {
      const error = BootstrapError(message: 'test');
      expect(error.detail, isNull);
    });
  });

  group('AppBootstrap.initError', () {
    test('starts as null', () {
      // Reset state from any previous test.
      AppBootstrap.initError = null;
      expect(AppBootstrap.initError, isNull);
    });

    test('can be set and read back', () {
      AppBootstrap.initError = const BootstrapError(
        message: 'Test error',
        detail: 'Detail',
      );
      expect(AppBootstrap.initError, isNotNull);
      expect(AppBootstrap.initError!.message, 'Test error');
      expect(AppBootstrap.initError!.detail, 'Detail');

      // Cleanup
      AppBootstrap.initError = null;
    });
  });
}
