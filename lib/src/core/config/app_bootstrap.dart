import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (_) {
      // The MVP can run entirely with mock data when no environment is present.
    }

    if (EnvConfig.hasSupabaseConfig) {
      try {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          publishableKey: EnvConfig.supabaseAnonKey,
        );
        EnvConfig.markSupabaseInitialized();
      } catch (_) {
        // Keep the preview usable with mock data if remote setup is incomplete.
      }
    }
  }
}
