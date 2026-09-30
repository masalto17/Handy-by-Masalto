import 'package:event_radio_app/src/shared/audio/audio_server_controller.dart';
import 'package:event_radio_app/src/shared/audio/audio_server_setting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Store en memoria, para probar el controlador sin el plugin de plataforma.
class _MemoryStore implements AudioServerStore {
  _MemoryStore([this.value]);

  String? value;
  bool failReads = false;

  @override
  Future<String?> readLocalUrl() async {
    if (failReads) throw Exception('almacenamiento no disponible');
    return value;
  }

  @override
  Future<void> writeLocalUrl(String? url) async => value = url;
}

void main() {
  const cloud = 'wss://handy-55hryzhr.livekit.cloud';

  group('validate', () {
    test('accepts ws and wss', () {
      expect(AudioServerSetting.validate('ws://192.168.1.50:7880'), isNull);
      expect(AudioServerSetting.validate('wss://audio.local:7880'), isNull);
    });

    test('rejects empty input', () {
      expect(
        AudioServerSetting.validate('   '),
        AudioServerUrlIssue.empty,
      );
    });

    test('rejects http/https: LiveKit habla WebSocket', () {
      expect(
        AudioServerSetting.validate('https://192.168.1.50:7880'),
        AudioServerUrlIssue.wrongScheme,
      );
      expect(
        AudioServerSetting.validate('http://192.168.1.50'),
        AudioServerUrlIssue.wrongScheme,
      );
    });

    test('rejects a bare host without scheme', () {
      // Sin esquema Uri.parse no falla, pero queda sin host utilizable.
      final issue = AudioServerSetting.validate('192.168.1.50:7880');
      expect(issue, isNotNull);
    });

    test('rejects a scheme without host', () {
      expect(
        AudioServerSetting.validate('ws://'),
        AudioServerUrlIssue.missingHost,
      );
    });
  });

  group('normalize', () {
    test('trims spaces and a trailing slash', () {
      expect(
        AudioServerSetting.normalize('  ws://192.168.1.50:7880/  '),
        'ws://192.168.1.50:7880',
      );
    });
  });

  group('effectiveUrl', () {
    test('uses the cloud server when no local one is set', () {
      expect(AudioServerSetting.cloud.effectiveUrl(cloud), cloud);
    });

    test('local wins over cloud', () {
      // Se configura justo cuando la nube no es confiable en ese predio.
      const setting = AudioServerSetting(localUrl: 'ws://192.168.1.50:7880');
      expect(setting.effectiveUrl(cloud), 'ws://192.168.1.50:7880');
    });

    test('local server works even when the build had no cloud URL', () {
      const setting = AudioServerSetting(localUrl: 'ws://192.168.1.50:7880');
      // Es el caso del predio sin internet con un APK sin LIVEKIT_URL.
      expect(setting.hasAnyServer(''), isTrue);
    });

    test('no server at all when neither is set', () {
      expect(AudioServerSetting.cloud.hasAnyServer(''), isFalse);
    });
  });

  group('AudioServerController', () {
    test('loads a previously saved local server', () async {
      final store = _MemoryStore('ws://192.168.1.50:7880');
      final controller = AudioServerController(store);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.state.usesLocalServer, isTrue);
      expect(controller.state.effectiveUrl(cloud), 'ws://192.168.1.50:7880');
    });

    test('falls back to cloud when storage fails', () async {
      final store = _MemoryStore()..failReads = true;
      final controller = AudioServerController(store);
      addTearDown(controller.dispose);

      await controller.load();
      // Un almacenamiento roto no puede dejar la app sin audio.
      expect(controller.state.usesLocalServer, isFalse);
    });

    test('useLocalServer persists a normalized URL', () async {
      final store = _MemoryStore();
      final controller = AudioServerController(store);
      addTearDown(controller.dispose);

      final issue = await controller.useLocalServer(' ws://10.0.0.7:7880/ ');
      expect(issue, isNull);
      expect(store.value, 'ws://10.0.0.7:7880');
      expect(controller.state.effectiveUrl(cloud), 'ws://10.0.0.7:7880');
    });

    test('useLocalServer rejects a bad URL without persisting it', () async {
      final store = _MemoryStore();
      final controller = AudioServerController(store);
      addTearDown(controller.dispose);

      final issue = await controller.useLocalServer('https://10.0.0.7');
      expect(issue, AudioServerUrlIssue.wrongScheme);
      // No debe quedar guardada una URL que no sirve.
      expect(store.value, isNull);
      expect(controller.state.usesLocalServer, isFalse);
    });

    test('useCloudServer clears the stored local URL', () async {
      final store = _MemoryStore('ws://10.0.0.7:7880');
      final controller = AudioServerController(store);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.useCloudServer();

      expect(store.value, isNull);
      expect(controller.state.effectiveUrl(cloud), cloud);
    });
  });
}
