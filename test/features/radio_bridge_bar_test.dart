import 'dart:async';

import 'package:event_radio_app/src/app/event_radio_app.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/audio/radio_bridge_status.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servicio de audio controlable desde el test.
///
/// Se usa en vez del mock de demo para poder poner al puente en un estado
/// concreto: lo que se prueba es que el operador lo vea, no como se conecta.
class _FakeAudioRoomService implements AudioRoomService {
  final _controller = StreamController<AudioRoomState>.broadcast();
  AudioRoomState _state = const AudioRoomState(byChannelId: {});

  void emit(AudioRoomState state) {
    _state = state;
    _controller.add(state);
  }

  @override
  AudioRoomState get state => _state;

  @override
  Stream<AudioRoomState> get stateChanges => _controller.stream;

  @override
  Stream<ReconnectionFailure> get reconnectionFailures => const Stream.empty();

  @override
  Future<void> prepareListening({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {}

  @override
  Future<void> startPushToTalk({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {}

  @override
  Future<void> stopPushToTalk() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

AudioRoomState _stateWith({
  required String channelId,
  required List<RadioBridgeStatus> bridges,
}) {
  return AudioRoomState(
    byChannelId: {
      channelId: ChannelPresence(
        channelId: channelId,
        channelName: 'Seguridad interna',
        isEmergency: false,
        isConnected: true,
        participantCount: 3,
        speakingNames: const [],
        radioBridges: bridges,
      ),
    },
  );
}

/// Entra al canal del evento demo y devuelve su id.
Future<String> _openChannel(
  WidgetTester tester,
  _FakeAudioRoomService audio,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioRoomServiceProvider.overrideWithValue(audio)],
      child: const EventRadioApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Join'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Join'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Seguridad interna'));
  await tester.pumpAndSettle();

  // Sin esto, un test que espera `findsNothing` pasaria igual aunque la
  // pantalla no hubiera cargado nunca.
  expect(find.text('PUSH-TO-TALK'), findsOneWidget);

  return 'channel-security';
}

/// Emite el estado y deja que el StreamBuilder lo tome.
///
/// Un solo `pump` corre el frame antes de que el stream entregue el evento,
/// asi que la pantalla todavia muestra el estado anterior.
Future<void> _emit(
  WidgetTester tester,
  _FakeAudioRoomService audio,
  AudioRoomState state,
) async {
  audio.emit(state);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sin puente en el canal no se muestra nada', (tester) async {
    final audio = _FakeAudioRoomService();
    addTearDown(audio.dispose);

    final channelId = await _openChannel(tester, audio);
    await _emit(
      tester,
      audio,
      _stateWith(channelId: channelId, bridges: const []),
    );

    // La mayoria de los eventos no tiene puente: no corresponde ocupar
    // pantalla con un estado vacio.
    expect(find.text('Radio link ready'), findsNothing);
    expect(find.text('No link status yet'), findsNothing);
  });

  testWidgets('el operador ve el enlace de radio listo', (tester) async {
    final audio = _FakeAudioRoomService();
    addTearDown(audio.dispose);

    final channelId = await _openChannel(tester, audio);
    await _emit(
      tester,
      audio,
      _stateWith(
        channelId: channelId,
        bridges: const [
          RadioBridgeStatus(name: 'Radio UHF', state: RadioBridgeState.idle),
        ],
      ),
    );

    expect(find.text('Radio UHF'), findsOneWidget);
    expect(find.text('Radio link ready'), findsOneWidget);
  });

  testWidgets('un corte por tiempo maximo se avisa con que hacer',
      (tester) async {
    final audio = _FakeAudioRoomService();
    addTearDown(audio.dispose);

    final channelId = await _openChannel(tester, audio);
    await _emit(
      tester,
      audio,
      _stateWith(
        channelId: channelId,
        bridges: const [
          RadioBridgeStatus(
            name: 'Radio UHF',
            state: RadioBridgeState.lockout,
            timeouts: 1,
          ),
        ],
      ),
    );

    expect(
      find.text('Transmission cut off: time limit reached'),
      findsOneWidget,
    );
    // Avisar sin decir que hacer deja al operador igual de trabado.
    expect(
      find.textContaining('nobody is holding PTT down'),
      findsOneWidget,
    );
  });

  testWidgets('los cortes previos se siguen informando ya normalizado',
      (tester) async {
    final audio = _FakeAudioRoomService();
    addTearDown(audio.dispose);

    final channelId = await _openChannel(tester, audio);
    await _emit(
      tester,
      audio,
      _stateWith(
        channelId: channelId,
        bridges: const [
          RadioBridgeStatus(
            name: 'Radio UHF',
            state: RadioBridgeState.idle,
            timeouts: 2,
          ),
        ],
      ),
    );

    // Que el enlace este bien ahora no borra que algo estuvo trabando el
    // canal de aire.
    expect(find.text('2 transmissions cut off so far'), findsOneWidget);
  });

  testWidgets('un canal desconectado no muestra estado del puente',
      (tester) async {
    final audio = _FakeAudioRoomService();
    addTearDown(audio.dispose);

    final channelId = await _openChannel(tester, audio);
    await _emit(
      tester,
      audio,
      AudioRoomState(
        byChannelId: {
          channelId: const ChannelPresence(
            channelId: 'channel-security',
            channelName: 'Seguridad interna',
            isEmergency: false,
            isConnected: false,
            participantCount: 0,
            speakingNames: [],
            radioBridges: [],
          ),
        },
      ),
    );

    expect(find.text('Radio link ready'), findsNothing);
  });
}
