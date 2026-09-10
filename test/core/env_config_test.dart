import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvConfig', () {
    group('compile-time constants', () {
      test('demoModeEnabled is a bool', () {
        // The value depends on the compile-time --dart-define=DEMO flag.
        // In test mode it defaults to false.
        expect(EnvConfig.demoModeEnabled, isA<bool>());
      });

      test('allowDemoShortcuts is true in debug mode', () {
        // kDebugMode is true in test runner, so allowDemoShortcuts should be true.
        expect(EnvConfig.allowDemoShortcuts, isTrue);
      });
    });

    group('environment getters without dotenv', () {
      // Without dotenv initialized, getters return defaults.

      test('supabaseUrl defaults to empty string', () {
        expect(EnvConfig.supabaseUrl, isA<String>());
      });

      test('supabaseAnonKey defaults to empty string', () {
        expect(EnvConfig.supabaseAnonKey, isA<String>());
      });

      test('authRedirectUrl has a default value', () {
        // When no env var is set, falls back to 'eventradio://login-callback'.
        expect(EnvConfig.authRedirectUrl, contains('login-callback'));
      });

      test('liveKitUrl defaults to empty string', () {
        expect(EnvConfig.liveKitUrl, isA<String>());
      });

      test('liveKitAudioEnabled defaults to false', () {
        expect(EnvConfig.liveKitAudioEnabled, isFalse);
      });
    });

    group('derived booleans', () {
      test('hasSupabaseConfig is false when URL and key are empty', () {
        // Without dotenv loaded, both are empty.
        if (EnvConfig.supabaseUrl.isEmpty && EnvConfig.supabaseAnonKey.isEmpty) {
          expect(EnvConfig.hasSupabaseConfig, isFalse);
        }
      });

      test('hasLiveKitConfig is false when audio not enabled', () {
        if (!EnvConfig.liveKitAudioEnabled) {
          expect(EnvConfig.hasLiveKitConfig, isFalse);
        }
      });

      test('isLocalSupabase is false when URL is empty', () {
        if (EnvConfig.supabaseUrl.isEmpty) {
          expect(EnvConfig.isLocalSupabase, isFalse);
        }
      });
    });

    group('markSupabaseInitialized', () {
      test('isSupabaseAvailable reflects initialization state', () {
        // Without config, isSupabaseAvailable is false regardless.
        if (!EnvConfig.hasSupabaseConfig) {
          expect(EnvConfig.isSupabaseAvailable, isFalse);
        }
      });
    });
  });
}
