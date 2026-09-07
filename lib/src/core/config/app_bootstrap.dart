import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error visible cuando la app no puede conectarse al backend en un build
/// que lo requiere (release sin DEMO).
class BootstrapError {
  const BootstrapError({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail != null ? '$message ($detail)' : message;
}

class AppBootstrap {
  const AppBootstrap._();

  /// Ultimo error de inicializacion, si lo hubo. Las pantallas pueden
  /// consultarlo para mostrar estado degradado en lugar de operar en silencio.
  static BootstrapError? initError;

  static Future<void> initialize() async {
    initError = null;

    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e) {
      // En modo demo/debug la app puede funcionar sin .env.
      // En release sin DEMO, la ausencia de config es un error real.
      if (!EnvConfig.allowDemoShortcuts) {
        initError = BootstrapError(
          message: 'No se pudo cargar la configuracion del entorno.',
          detail: e.toString(),
        );
        return;
      }
    }

    if (EnvConfig.hasSupabaseConfig) {
      try {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          publishableKey: EnvConfig.supabaseAnonKey,
        );
        EnvConfig.markSupabaseInitialized();
      } catch (e) {
        initError = BootstrapError(
          message: 'No se pudo conectar con Supabase.',
          detail: e.toString(),
        );
        // En modo demo/debug se permite continuar con datos mock.
        // En release sin DEMO esto deja initError visible para que la UI
        // bloquee operacion o muestre advertencia.
        if (!EnvConfig.allowDemoShortcuts) {
          return;
        }
      }
    } else if (!EnvConfig.allowDemoShortcuts) {
      // Release sin config de Supabase: la app no puede operar.
      initError = const BootstrapError(
        message: 'Configuracion de Supabase ausente.',
        detail:
            'SUPABASE_URL y SUPABASE_ANON_KEY son obligatorios en builds de produccion.',
      );
    }
  }
}
