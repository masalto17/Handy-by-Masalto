import 'dart:async';

import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final audioRoomServiceProvider = Provider<AudioRoomService>((ref) {
  final service = EnvConfig.hasLiveKitConfig
      ? LiveKitAudioRoomService(
          serverUrl: EnvConfig.liveKitUrl,
          tokenProvider: SupabaseLiveKitTokenProvider().call,
        )
      : MockAudioRoomService();

  ref.onDispose(service.dispose);
  return service;
});

/// Presencia de un canal conectado: cuanta gente hay en la sala y quien
/// esta hablando ahora.
class ChannelPresence {
  const ChannelPresence({
    required this.channelId,
    required this.channelName,
    required this.isEmergency,
    required this.isConnected,
    required this.participantCount,
    required this.speakingNames,
  });

  final String channelId;
  final String channelName;
  final bool isEmergency;
  final bool isConnected;

  /// Participantes en la sala, incluyendo este dispositivo.
  final int participantCount;
  final List<String> speakingNames;

  bool get someoneSpeaking => speakingNames.isNotEmpty;
}

class AudioRoomState {
  const AudioRoomState({this.byChannelId = const {}});

  final Map<String, ChannelPresence> byChannelId;

  ChannelPresence? forChannel(String channelId) => byChannelId[channelId];

  bool get emergencySpeaking => byChannelId.values.any(
        (presence) => presence.isEmergency && presence.someoneSpeaking,
      );

  static const empty = AudioRoomState();
}

abstract class AudioRoomService {
  Future<void> prepareListening({
    required EventSession session,
    required List<EventChannel> channels,
  });

  Future<void> startPushToTalk({
    required EventSession session,
    required List<EventChannel> channels,
  });

  Future<void> stopPushToTalk();

  /// Corta todas las salas conectadas. Se llama al salir de la pantalla de
  /// canal para no consumir minutos LiveKit sin necesidad.
  Future<void> stopListening();

  AudioRoomState get state;

  Stream<AudioRoomState> get stateChanges;

  Future<void> dispose();
}

class AudioRoomTarget {
  const AudioRoomTarget({
    required this.eventId,
    required this.participantId,
    required this.channel,
  });

  final String eventId;
  final String participantId;
  final EventChannel channel;

  String get roomName => channel.livekitRoomName;
}

typedef LiveKitTokenProvider = FutureOr<String> Function(
    AudioRoomTarget target);

class AudioRoomConfigurationException implements Exception {
  const AudioRoomConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockAudioRoomService implements AudioRoomService {
  bool _isTransmitting = false;

  @override
  AudioRoomState get state => AudioRoomState.empty;

  @override
  Stream<AudioRoomState> get stateChanges =>
      const Stream<AudioRoomState>.empty();

  @override
  Future<void> prepareListening({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {}

  @override
  Future<void> startPushToTalk({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {
    _isTransmitting = channels.isNotEmpty;
  }

  @override
  Future<void> stopPushToTalk() async {
    _isTransmitting = false;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {
    if (_isTransmitting) {
      await stopPushToTalk();
    }
  }
}

class SupabaseLiveKitTokenProvider {
  SupabaseLiveKitTokenProvider({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> call(AudioRoomTarget target) async {
    final response = await _client.functions.invoke(
      'livekit-token',
      body: {'channel_id': target.channel.id},
    );
    final data = response.data;
    if (data is! Map) {
      throw const AudioRoomConfigurationException(
        'Respuesta invalida del token LiveKit.',
      );
    }
    final token = data['participant_token'] as String?;
    if (token == null || token.isEmpty) {
      final error = data['error'] as String?;
      throw AudioRoomConfigurationException(
        error ?? 'No pudimos obtener token LiveKit.',
      );
    }
    return token;
  }
}

class _RoomSession {
  _RoomSession({
    required this.room,
    required this.listener,
    required this.target,
  });

  final livekit.Room room;
  final livekit.EventsListener<livekit.RoomEvent> listener;
  final AudioRoomTarget target;

  EventChannel get channel => target.channel;
  List<String> speakingNames = const [];
  int reconnectAttempts = 0;

  Future<void> close() async {
    await listener.dispose();
    await room.disconnect();
    await room.dispose();
  }
}

class LiveKitAudioRoomService implements AudioRoomService {
  LiveKitAudioRoomService({
    required this.serverUrl,
    required this.tokenProvider,
  });

  static const int _maxReconnectAttempts = 3;

  final String serverUrl;
  final LiveKitTokenProvider tokenProvider;

  final Map<String, _RoomSession> _sessionsByRoomName = {};

  /// Salas conectadas para escucha continua (pantalla de canal). Las salas
  /// abiertas solo para un PTT puntual (broadcast) se cierran al soltar el
  /// boton para no gastar minutos LiveKit.
  final Set<String> _listeningRoomNames = {};
  final Set<String> _intentionalDisconnects = {};

  final StreamController<AudioRoomState> _stateController =
      StreamController<AudioRoomState>.broadcast();
  AudioRoomState _state = AudioRoomState.empty;
  bool _isDisposed = false;

  @override
  AudioRoomState get state => _state;

  @override
  Stream<AudioRoomState> get stateChanges => _stateController.stream;

  @override
  Future<void> prepareListening({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {
    if (channels.isEmpty) return;

    for (final channel in channels) {
      final target = AudioRoomTarget(
        eventId: session.event.id,
        participantId: session.participant.id,
        channel: channel,
      );
      final roomSession = await _sessionFor(target);
      _listeningRoomNames.add(target.roomName);
      await roomSession.room.localParticipant?.setMicrophoneEnabled(false);
    }
  }

  @override
  Future<void> startPushToTalk({
    required EventSession session,
    required List<EventChannel> channels,
  }) async {
    if (channels.isEmpty) return;

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw const AudioRoomConfigurationException(
        'Permiso de microfono denegado.',
      );
    }

    Object? firstError;
    var publishedCount = 0;
    for (final channel in channels) {
      try {
        final target = AudioRoomTarget(
          eventId: session.event.id,
          participantId: session.participant.id,
          channel: channel,
        );
        final roomSession = await _sessionFor(target);
        await roomSession.room.localParticipant?.setMicrophoneEnabled(true);
        publishedCount++;
      } catch (error) {
        // En broadcast, un canal caido no debe frenar la transmision al
        // resto de los canales.
        firstError ??= error;
      }
    }

    if (publishedCount == 0 && firstError != null) {
      throw AudioRoomConfigurationException(
        firstError is AudioRoomConfigurationException
            ? firstError.message
            : 'No pudimos iniciar el audio PTT.',
      );
    }
  }

  @override
  Future<void> stopPushToTalk() async {
    for (final roomSession in _sessionsByRoomName.values) {
      try {
        await roomSession.room.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {
        // Seguir apagando el resto de los microfonos.
      }
    }

    // Cerrar las salas abiertas solo para este PTT (por ejemplo broadcast a
    // canales que no se estaban escuchando) para no consumir minutos.
    final transientRoomNames = _sessionsByRoomName.keys
        .where((name) => !_listeningRoomNames.contains(name))
        .toList();
    for (final roomName in transientRoomNames) {
      await _closeRoom(roomName);
    }
    _recomputeState();
  }

  @override
  Future<void> stopListening() async {
    final roomNames = _sessionsByRoomName.keys.toList();
    for (final roomName in roomNames) {
      await _closeRoom(roomName);
    }
    _listeningRoomNames.clear();
    _recomputeState();
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await stopListening();
    await _stateController.close();
  }

  Future<void> _closeRoom(String roomName) async {
    final roomSession = _sessionsByRoomName.remove(roomName);
    if (roomSession == null) return;
    _intentionalDisconnects.add(roomName);
    try {
      await roomSession.close();
    } catch (_) {
      // La sala ya estaba caida; el estado local queda limpio igual.
    } finally {
      _intentionalDisconnects.remove(roomName);
    }
  }

  Future<_RoomSession> _sessionFor(AudioRoomTarget target) async {
    final existing = _sessionsByRoomName[target.roomName];
    if (existing != null &&
        existing.room.connectionState !=
            livekit.ConnectionState.disconnected) {
      return existing;
    }
    if (existing != null) {
      await _closeRoom(target.roomName);
    }

    // Token siempre fresco: LiveKit valida el token al conectar, por lo que
    // pedir uno nuevo en cada (re)conexion evita expiraciones.
    final token = await tokenProvider(target);
    final room = livekit.Room(
      roomOptions: const livekit.RoomOptions(
        defaultAudioCaptureOptions: livekit.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );
    final listener = room.createListener();
    final roomSession = _RoomSession(
      room: room,
      listener: listener,
      target: target,
    );
    _attachRoomEvents(roomSession);

    await room.connect(
      serverUrl,
      token,
      connectOptions: const livekit.ConnectOptions(autoSubscribe: true),
    );
    await room.localParticipant?.setMicrophoneEnabled(false);
    _sessionsByRoomName[target.roomName] = roomSession;
    _recomputeState();
    return roomSession;
  }

  void _attachRoomEvents(_RoomSession roomSession) {
    roomSession.listener
      ..on<livekit.ParticipantConnectedEvent>((_) => _recomputeState())
      ..on<livekit.ParticipantDisconnectedEvent>((_) => _recomputeState())
      ..on<livekit.ActiveSpeakersChangedEvent>((event) {
        roomSession.speakingNames = event.speakers
            .map((speaker) =>
                speaker.name.isNotEmpty ? speaker.name : speaker.identity)
            .toList();
        _applyEmergencyDucking();
        _recomputeState();
      })
      ..on<livekit.RoomDisconnectedEvent>((_) {
        roomSession.speakingNames = const [];
        _recomputeState();
        final roomName = roomSession.target.roomName;
        if (!_isDisposed && !_intentionalDisconnects.contains(roomName)) {
          unawaited(_scheduleReconnect(roomSession));
        }
      });
  }

  Future<void> _scheduleReconnect(_RoomSession roomSession) async {
    final roomName = roomSession.target.roomName;
    while (roomSession.reconnectAttempts < _maxReconnectAttempts) {
      roomSession.reconnectAttempts++;
      await Future<void>.delayed(
        Duration(seconds: 2 * roomSession.reconnectAttempts),
      );
      if (_isDisposed ||
          _intentionalDisconnects.contains(roomName) ||
          _sessionsByRoomName[roomName] != roomSession) {
        return;
      }
      try {
        _sessionsByRoomName.remove(roomName);
        await roomSession.close();
        await _sessionFor(roomSession.target);
        return;
      } catch (_) {
        // Reintentar con backoff hasta agotar los intentos.
      }
    }
    _recomputeState();
  }

  /// Mientras alguien habla en un canal de emergencia, silencia el audio del
  /// resto de los canales para que la alerta se escuche limpia. Al liberarse
  /// el canal de emergencia se restaura el audio normal.
  void _applyEmergencyDucking() {
    final emergencyActive = _sessionsByRoomName.values.any(
      (roomSession) =>
          roomSession.channel.isEmergency &&
          roomSession.speakingNames.isNotEmpty,
    );

    for (final roomSession in _sessionsByRoomName.values) {
      if (roomSession.channel.isEmergency) continue;
      final shouldMute = emergencyActive;
      for (final participant in roomSession.room.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          unawaited(
            Future<void>(() async {
              try {
                if (shouldMute) {
                  await publication.disable();
                } else {
                  await publication.enable();
                }
              } catch (_) {
                // Si la pista ya no existe, no hay nada que silenciar.
              }
            }),
          );
        }
      }
    }
  }

  void _recomputeState() {
    if (_isDisposed) return;
    final presences = <String, ChannelPresence>{};
    for (final roomSession in _sessionsByRoomName.values) {
      final room = roomSession.room;
      final isConnected =
          room.connectionState == livekit.ConnectionState.connected;
      presences[roomSession.channel.id] = ChannelPresence(
        channelId: roomSession.channel.id,
        channelName: roomSession.channel.name,
        isEmergency: roomSession.channel.isEmergency,
        isConnected: isConnected,
        participantCount: isConnected ? room.remoteParticipants.length + 1 : 0,
        speakingNames: roomSession.speakingNames,
      );
    }
    _state = AudioRoomState(byChannelId: presences);
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
