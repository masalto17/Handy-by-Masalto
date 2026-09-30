import 'dart:async';

import 'package:event_radio_app/src/shared/audio/audio_server_setting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lee y guarda la configuracion del servidor de audio.
///
/// Se abstrae del almacenamiento para poder testear la logica sin depender
/// del plugin de plataforma.
abstract class AudioServerStore {
  /// Devuelve la URL local guardada, o `null` si no hay ninguna.
  Future<String?> readLocalUrl();

  /// Guarda la URL local; `null` la borra.
  Future<void> writeLocalUrl(String? url);
}

/// Implementacion sobre `shared_preferences`.
class PrefsAudioServerStore implements AudioServerStore {
  /// Crea el store.
  const PrefsAudioServerStore();

  static const _key = 'audio_server_local_url';

  @override
  Future<String?> readLocalUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> writeLocalUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, url);
    }
  }
}

/// Estado del servidor de audio, persistido en el dispositivo.
///
/// Se guarda localmente y no en el backend a proposito: es justamente la
/// configuracion que hay que poder cambiar cuando el backend no se alcanza.
class AudioServerController extends StateNotifier<AudioServerSetting> {
  /// Crea el controlador y carga lo guardado.
  AudioServerController(this._store) : super(AudioServerSetting.cloud) {
    unawaited(load());
  }

  final AudioServerStore _store;

  /// Carga la configuracion guardada. Un fallo de lectura deja la de nube,
  /// que es el comportamiento previo: nunca bloquea el arranque.
  Future<void> load() async {
    try {
      final url = await _store.readLocalUrl();
      if (!mounted) return;
      state = AudioServerSetting(localUrl: url);
    } catch (_) {
      if (mounted) state = AudioServerSetting.cloud;
    }
  }

  /// Apunta el audio a un servidor local. Devuelve el problema encontrado,
  /// o `null` si quedo aplicada.
  Future<AudioServerUrlIssue?> useLocalServer(String rawUrl) async {
    final normalized = AudioServerSetting.normalize(rawUrl);
    final issue = AudioServerSetting.validate(normalized);
    if (issue != null) return issue;

    await _store.writeLocalUrl(normalized);
    if (mounted) state = AudioServerSetting(localUrl: normalized);
    return null;
  }

  /// Vuelve al servidor de la nube que trae el build.
  Future<void> useCloudServer() async {
    await _store.writeLocalUrl(null);
    if (mounted) state = AudioServerSetting.cloud;
  }
}

/// Configuracion del servidor de audio de este dispositivo.
final audioServerProvider =
    StateNotifierProvider<AudioServerController, AudioServerSetting>((ref) {
  return AudioServerController(const PrefsAudioServerStore());
});
