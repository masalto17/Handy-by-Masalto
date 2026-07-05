import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  const EnvConfig._();

  /// Compile-time demo switch: `flutter build ... --dart-define=DEMO=true`.
  /// Demo shortcuts (mock admin login, prefilled invite codes) quedan fuera
  /// de los builds de release salvo que DEMO se active explicitamente.
  static const bool demoModeEnabled = bool.fromEnvironment('DEMO');
  static const bool allowDemoShortcuts = demoModeEnabled || kDebugMode;

  static Map<String, String> get _env => dotenv.isInitialized ? dotenv.env : {};
  static bool _isSupabaseInitialized = false;

  static String get supabaseUrl => _env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => _env['SUPABASE_ANON_KEY'] ?? '';
  static String get authRedirectUrl =>
      _env['AUTH_REDIRECT_URL'] ?? 'eventradio://login-callback';
  static String get liveKitUrl => _env['LIVEKIT_URL'] ?? '';
  static bool get liveKitAudioEnabled =>
      (_env['LIVEKIT_AUDIO_ENABLED'] ?? '').toLowerCase() == 'true';

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get isLocalSupabase =>
      supabaseUrl.contains('127.0.0.1') || supabaseUrl.contains('localhost');
  static bool get hasLiveKitConfig =>
      liveKitAudioEnabled && liveKitUrl.isNotEmpty;

  static bool get isSupabaseAvailable =>
      hasSupabaseConfig && _isSupabaseInitialized;

  static void markSupabaseInitialized() {
    _isSupabaseInitialized = true;
  }
}
