import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelPresence', () {
    test('someoneSpeaking is true when speakingNames is not empty', () {
      const presence = ChannelPresence(
        channelId: 'ch-1',
        channelName: 'Seguridad',
        isEmergency: false,
        isConnected: true,
        participantCount: 3,
        speakingNames: ['Laura'],
      );
      expect(presence.someoneSpeaking, isTrue);
    });

    test('someoneSpeaking is false when speakingNames is empty', () {
      const presence = ChannelPresence(
        channelId: 'ch-1',
        channelName: 'Seguridad',
        isEmergency: false,
        isConnected: true,
        participantCount: 3,
        speakingNames: [],
      );
      expect(presence.someoneSpeaking, isFalse);
    });
  });

  group('AudioRoomState', () {
    test('empty state has no channels', () {
      expect(AudioRoomState.empty.byChannelId, isEmpty);
      expect(AudioRoomState.empty.forChannel('any'), isNull);
      expect(AudioRoomState.empty.emergencySpeaking, isFalse);
    });

    test('forChannel returns presence for known channel', () {
      const presence = ChannelPresence(
        channelId: 'ch-1',
        channelName: 'Produccion',
        isEmergency: false,
        isConnected: true,
        participantCount: 2,
        speakingNames: [],
      );
      const state = AudioRoomState(byChannelId: {'ch-1': presence});

      expect(state.forChannel('ch-1'), isNotNull);
      expect(state.forChannel('ch-1')!.channelName, 'Produccion');
      expect(state.forChannel('ch-unknown'), isNull);
    });

    test('emergencySpeaking is true only when emergency channel has speakers',
        () {
      const emergencyPresence = ChannelPresence(
        channelId: 'ch-emer',
        channelName: 'Emergencia',
        isEmergency: true,
        isConnected: true,
        participantCount: 2,
        speakingNames: ['Marcos'],
      );
      const normalPresence = ChannelPresence(
        channelId: 'ch-prod',
        channelName: 'Produccion',
        isEmergency: false,
        isConnected: true,
        participantCount: 3,
        speakingNames: ['Laura'],
      );

      const withEmergencySpeaking = AudioRoomState(byChannelId: {
        'ch-emer': emergencyPresence,
        'ch-prod': normalPresence,
      });
      expect(withEmergencySpeaking.emergencySpeaking, isTrue);

      const silentEmergency = ChannelPresence(
        channelId: 'ch-emer',
        channelName: 'Emergencia',
        isEmergency: true,
        isConnected: true,
        participantCount: 2,
        speakingNames: [],
      );
      const withoutEmergencySpeaking = AudioRoomState(byChannelId: {
        'ch-emer': silentEmergency,
        'ch-prod': normalPresence,
      });
      expect(withoutEmergencySpeaking.emergencySpeaking, isFalse);
    });

    test('emergencySpeaking is false when normal channels speak', () {
      const normalSpeaking = ChannelPresence(
        channelId: 'ch-prod',
        channelName: 'Produccion',
        isEmergency: false,
        isConnected: true,
        participantCount: 3,
        speakingNames: ['Laura'],
      );
      const state = AudioRoomState(byChannelId: {'ch-prod': normalSpeaking});
      expect(state.emergencySpeaking, isFalse);
    });
  });

  group('ReconnectionFailure', () {
    test('stores channel info and attempt count', () {
      const failure = ReconnectionFailure(
        channelId: 'ch-1',
        channelName: 'Seguridad',
        attempts: 3,
      );
      expect(failure.channelId, 'ch-1');
      expect(failure.channelName, 'Seguridad');
      expect(failure.attempts, 3);
    });
  });

  group('AudioRoomConfigurationException', () {
    test('toString returns code name when no serverMessage', () {
      const exception =
          AudioRoomConfigurationException(AudioRoomErrorCode.microphoneDenied);
      expect(exception.toString(), 'microphoneDenied');
      expect(exception.message, 'microphoneDenied');
      expect(exception.code, AudioRoomErrorCode.microphoneDenied);
    });

    test('toString returns serverMessage when provided', () {
      const exception = AudioRoomConfigurationException(
        AudioRoomErrorCode.tokenFetchFailed,
        serverMessage: 'Custom server error',
      );
      expect(exception.toString(), 'Custom server error');
      expect(exception.message, 'Custom server error');
      expect(exception.code, AudioRoomErrorCode.tokenFetchFailed);
    });
  });

  group('MockAudioRoomService', () {
    late MockAudioRoomService service;

    setUp(() {
      service = MockAudioRoomService();
    });

    test('starts with empty state', () {
      expect(service.state.byChannelId, isEmpty);
    });

    test('stateChanges emits nothing', () {
      expect(service.stateChanges, emitsDone);
    });

    test('reconnectionFailures emits nothing', () {
      expect(service.reconnectionFailures, emitsDone);
    });

    test('dispose completes without error', () async {
      await expectLater(service.dispose(), completes);
    });

    test('prepareListening completes without error', () async {
      await expectLater(
        service.prepareListening(session: _dummySession, channels: []),
        completes,
      );
    });

    test('start and stop PTT cycle completes', () async {
      await service.startPushToTalk(
        session: _dummySession,
        channels: _dummySession.channels,
      );
      await service.stopPushToTalk();
      await expectLater(service.dispose(), completes);
    });

    test('stopListening completes without error', () async {
      await expectLater(service.stopListening(), completes);
    });
  });
}

// -- Helpers -----------------------------------------------------------------

final _dummySession = EventSession(
  event: EventRadioEvent(
    id: 'event-1',
    name: 'Test Event',
    startsAt: DateTime(2026, 6, 23, 10),
    endsAt: DateTime(2026, 6, 23, 22),
    status: EventStatus.active,
  ),
  participant: const EventParticipant(
    id: 'p-1',
    eventId: 'event-1',
    displayName: 'Test User',
    role: ParticipantRole.admin,
    inviteCode: 'TEST01',
    inviteStatus: 'accepted',
  ),
  channels: const [
    EventChannel(
      id: 'ch-1',
      eventId: 'event-1',
      name: 'Produccion',
      code: 'produccion',
      livekitRoomName: 'event-1_produccion',
    ),
  ],
  permissions: const [
    ChannelPermission(channelId: 'ch-1', participantId: 'p-1'),
  ],
);
