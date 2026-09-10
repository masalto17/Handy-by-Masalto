import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -------------------------------------------------------------------------
  // EventRadioEvent
  // -------------------------------------------------------------------------

  group('EventRadioEvent.fromMap', () {
    test('parses a full map', () {
      final event = EventRadioEvent.fromMap({
        'id': 'ev-1',
        'name': 'SATI-26',
        'description': 'Congreso',
        'starts_at': '2026-06-23T10:00:00Z',
        'ends_at': '2026-06-23T22:00:00Z',
        'status': 'active',
        'created_by': 'user-1',
      });

      expect(event.id, 'ev-1');
      expect(event.name, 'SATI-26');
      expect(event.description, 'Congreso');
      expect(event.status, EventStatus.active);
      expect(event.createdBy, 'user-1');
    });

    test('defaults status to draft for unknown value', () {
      final event = EventRadioEvent.fromMap({
        'id': 'ev-1',
        'name': 'Test',
        'starts_at': '2026-06-23T10:00:00Z',
        'ends_at': '2026-06-23T22:00:00Z',
        'status': 'unknown_status',
      });
      expect(event.status, EventStatus.draft);
    });

    test('defaults status to draft when null', () {
      final event = EventRadioEvent.fromMap({
        'id': 'ev-1',
        'name': 'Test',
        'starts_at': '2026-06-23T10:00:00Z',
        'ends_at': '2026-06-23T22:00:00Z',
      });
      expect(event.status, EventStatus.draft);
    });
  });

  group('EventRadioEvent.isClosed', () {
    test('closed status is considered closed', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23),
        endsAt: DateTime(2026, 6, 24),
        status: EventStatus.closed,
      );
      expect(event.isClosed, isTrue);
    });

    test('cancelled status is considered closed', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23),
        endsAt: DateTime(2026, 6, 24),
        status: EventStatus.cancelled,
      );
      expect(event.isClosed, isTrue);
    });

    test('active status is not closed', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23),
        endsAt: DateTime(2026, 6, 24),
        status: EventStatus.active,
      );
      expect(event.isClosed, isFalse);
    });
  });

  group('EventRadioEvent.copyWith', () {
    test('overrides specified fields', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Original',
        startsAt: DateTime(2026, 6, 23),
        endsAt: DateTime(2026, 6, 24),
        status: EventStatus.active,
      );
      final updated = event.copyWith(name: 'Updated', status: EventStatus.closed);

      expect(updated.id, 'ev-1');
      expect(updated.name, 'Updated');
      expect(updated.status, EventStatus.closed);
    });
  });

  group('EventRadioEvent.isOperational edge cases', () {
    test('not operational before startsAt', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23, 10),
        endsAt: DateTime(2026, 6, 23, 22),
        status: EventStatus.active,
      );
      expect(event.isOperational(DateTime(2026, 6, 23, 9)), isFalse);
    });

    test('operational exactly at startsAt', () {
      final startsAt = DateTime(2026, 6, 23, 10);
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: startsAt,
        endsAt: DateTime(2026, 6, 23, 22),
        status: EventStatus.active,
      );
      expect(event.isOperational(startsAt), isTrue);
    });

    test('not operational at endsAt (exclusive)', () {
      final endsAt = DateTime(2026, 6, 23, 22);
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23, 10),
        endsAt: endsAt,
        status: EventStatus.active,
      );
      expect(event.isOperational(endsAt), isFalse);
    });

    test('not operational when status is scheduled', () {
      final event = EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23, 10),
        endsAt: DateTime(2026, 6, 23, 22),
        status: EventStatus.scheduled,
      );
      expect(event.isOperational(DateTime(2026, 6, 23, 12)), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // EventChannel
  // -------------------------------------------------------------------------

  group('EventChannel.fromMap', () {
    test('parses a full map', () {
      final channel = EventChannel.fromMap({
        'id': 'ch-1',
        'event_id': 'ev-1',
        'name': 'Seguridad',
        'code': 'seguridad',
        'description': 'Canal de seguridad',
        'priority': 50,
        'is_emergency': true,
        'livekit_room_name': 'ev-1_seguridad',
      });

      expect(channel.id, 'ch-1');
      expect(channel.name, 'Seguridad');
      expect(channel.code, 'seguridad');
      expect(channel.description, 'Canal de seguridad');
      expect(channel.priority, 50);
      expect(channel.isEmergency, isTrue);
      expect(channel.livekitRoomName, 'ev-1_seguridad');
    });

    test('defaults priority to 0 and isEmergency to false', () {
      final channel = EventChannel.fromMap({
        'id': 'ch-1',
        'event_id': 'ev-1',
        'name': 'Produccion',
        'code': 'produccion',
        'livekit_room_name': 'ev-1_produccion',
      });

      expect(channel.priority, 0);
      expect(channel.isEmergency, isFalse);
      expect(channel.description, isNull);
    });
  });

  group('EventChannel.copyWith', () {
    test('overrides specified fields', () {
      const channel = EventChannel(
        id: 'ch-1',
        eventId: 'ev-1',
        name: 'Original',
        code: 'original',
        livekitRoomName: 'ev-1_original',
      );
      final updated = channel.copyWith(
        name: 'Updated',
        priority: 99,
        isEmergency: true,
      );

      expect(updated.id, 'ch-1');
      expect(updated.name, 'Updated');
      expect(updated.code, 'original');
      expect(updated.priority, 99);
      expect(updated.isEmergency, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // EventParticipant
  // -------------------------------------------------------------------------

  group('EventParticipant.fromMap', () {
    test('parses a full map', () {
      final participant = EventParticipant.fromMap({
        'id': 'p-1',
        'event_id': 'ev-1',
        'auth_user_id': 'auth-1',
        'display_name': 'Laura C.',
        'phone': '+54 9 264 555-0100',
        'role': 'admin',
        'invite_code': 'SATI26',
        'invite_status': 'accepted',
        'joined_at': '2026-06-23T10:05:00Z',
      });

      expect(participant.id, 'p-1');
      expect(participant.displayName, 'Laura C.');
      expect(participant.role, ParticipantRole.admin);
      expect(participant.inviteCode, 'SATI26');
      expect(participant.joinedAt, isNotNull);
      expect(participant.authUserId, 'auth-1');
    });

    test('defaults role to participant and invite_status to pending', () {
      final participant = EventParticipant.fromMap({
        'id': 'p-1',
        'event_id': 'ev-1',
        'display_name': 'Test',
        'invite_code': 'TEST01',
      });

      expect(participant.role, ParticipantRole.participant);
      expect(participant.inviteStatus, 'pending');
      expect(participant.joinedAt, isNull);
      expect(participant.authUserId, isNull);
      expect(participant.phone, isNull);
    });
  });

  group('EventParticipant.canAccessAdmin', () {
    test('admin can access', () {
      const participant = EventParticipant(
        id: 'p-1',
        eventId: 'ev-1',
        displayName: 'Admin',
        role: ParticipantRole.admin,
        inviteCode: 'A01',
        inviteStatus: 'accepted',
      );
      expect(participant.canAccessAdmin, isTrue);
    });

    test('coordinator can access', () {
      const participant = EventParticipant(
        id: 'p-1',
        eventId: 'ev-1',
        displayName: 'Coord',
        role: ParticipantRole.coordinator,
        inviteCode: 'C01',
        inviteStatus: 'accepted',
      );
      expect(participant.canAccessAdmin, isTrue);
    });

    test('participant cannot access', () {
      const participant = EventParticipant(
        id: 'p-1',
        eventId: 'ev-1',
        displayName: 'User',
        role: ParticipantRole.participant,
        inviteCode: 'U01',
        inviteStatus: 'accepted',
      );
      expect(participant.canAccessAdmin, isFalse);
    });

    test('viewer cannot access', () {
      const participant = EventParticipant(
        id: 'p-1',
        eventId: 'ev-1',
        displayName: 'Viewer',
        role: ParticipantRole.viewer,
        inviteCode: 'V01',
        inviteStatus: 'accepted',
      );
      expect(participant.canAccessAdmin, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // EventSession helpers
  // -------------------------------------------------------------------------

  group('EventSession', () {
    final session = EventSession(
      event: EventRadioEvent(
        id: 'ev-1',
        name: 'Test',
        startsAt: DateTime(2026, 6, 23, 10),
        endsAt: DateTime(2026, 6, 23, 22),
        status: EventStatus.active,
      ),
      participant: const EventParticipant(
        id: 'p-1',
        eventId: 'ev-1',
        displayName: 'Laura',
        role: ParticipantRole.admin,
        inviteCode: 'SATI26',
        inviteStatus: 'accepted',
      ),
      channels: const [
        EventChannel(
          id: 'ch-prod',
          eventId: 'ev-1',
          name: 'Produccion',
          code: 'produccion',
          priority: 10,
          livekitRoomName: 'ev-1_produccion',
        ),
        EventChannel(
          id: 'ch-sec',
          eventId: 'ev-1',
          name: 'Seguridad',
          code: 'seguridad',
          priority: 50,
          livekitRoomName: 'ev-1_seguridad',
          isEmergency: true,
        ),
        EventChannel(
          id: 'ch-acc',
          eventId: 'ev-1',
          name: 'Accesos',
          code: 'accesos',
          priority: 30,
          livekitRoomName: 'ev-1_accesos',
        ),
      ],
      permissions: const [
        ChannelPermission(channelId: 'ch-prod', participantId: 'p-1'),
        ChannelPermission(
          channelId: 'ch-sec',
          participantId: 'p-1',
          canTalk: false,
        ),
      ],
      participants: const [
        EventParticipant(
          id: 'p-1',
          eventId: 'ev-1',
          displayName: 'Laura',
          role: ParticipantRole.admin,
          inviteCode: 'SATI26',
          inviteStatus: 'accepted',
        ),
        EventParticipant(
          id: 'p-2',
          eventId: 'ev-1',
          displayName: 'Marcos',
          role: ParticipantRole.participant,
          inviteCode: 'MARCOS26',
          inviteStatus: 'accepted',
        ),
      ],
      allPermissions: const [
        ChannelPermission(channelId: 'ch-prod', participantId: 'p-1'),
        ChannelPermission(
          channelId: 'ch-sec',
          participantId: 'p-1',
          canTalk: false,
        ),
        ChannelPermission(channelId: 'ch-prod', participantId: 'p-2'),
      ],
    );

    test('orderedChannels sorts by priority descending', () {
      final ordered = session.orderedChannels;
      expect(ordered[0].code, 'seguridad'); // priority 50
      expect(ordered[1].code, 'accesos'); // priority 30
      expect(ordered[2].code, 'produccion'); // priority 10
    });

    test('channelById returns channel or null', () {
      expect(session.channelById('ch-prod')?.name, 'Produccion');
      expect(session.channelById('ch-unknown'), isNull);
    });

    test('permissionFor returns permission for current participant', () {
      final prodPerm = session.permissionFor('ch-prod');
      expect(prodPerm, isNotNull);
      expect(prodPerm!.canTalk, isTrue);

      final secPerm = session.permissionFor('ch-sec');
      expect(secPerm, isNotNull);
      expect(secPerm!.canTalk, isFalse);

      expect(session.permissionFor('ch-unknown'), isNull);
    });

    test('permissionForParticipant looks up across all permissions', () {
      final perm = session.permissionForParticipant(
        participantId: 'p-2',
        channelId: 'ch-prod',
      );
      expect(perm, isNotNull);
      expect(perm!.canTalk, isTrue);

      final noPerm = session.permissionForParticipant(
        participantId: 'p-2',
        channelId: 'ch-sec',
      );
      expect(noPerm, isNull);
    });

    test('copyWith overrides specified fields', () {
      final updated = session.copyWith(
        channels: const [],
        permissions: const [],
      );
      expect(updated.channels, isEmpty);
      expect(updated.permissions, isEmpty);
      expect(updated.event.name, 'Test');
      expect(updated.participant.displayName, 'Laura');
    });
  });

  // -------------------------------------------------------------------------
  // ChannelPermission
  // -------------------------------------------------------------------------

  group('ChannelPermission', () {
    test('defaults to full access', () {
      const perm = ChannelPermission(
        channelId: 'ch-1',
        participantId: 'p-1',
      );
      expect(perm.canListen, isTrue);
      expect(perm.canTalk, isTrue);
      expect(perm.canViewHistory, isTrue);
    });

    test('copyWith overrides specified fields', () {
      const perm = ChannelPermission(
        channelId: 'ch-1',
        participantId: 'p-1',
      );
      final updated = perm.copyWith(canTalk: false, canViewHistory: false);

      expect(updated.canListen, isTrue);
      expect(updated.canTalk, isFalse);
      expect(updated.canViewHistory, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // VoiceMessage edge cases
  // -------------------------------------------------------------------------

  group('VoiceMessage', () {
    test('hasAudio is false when both urls are null', () {
      final msg = VoiceMessage.fromMap({
        'id': 'm-1',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(msg.hasAudio, isFalse);
    });

    test('isTranscriptionFinal for failed and skipped statuses', () {
      final failed = VoiceMessage.fromMap({
        'id': 'm-1',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'transcription_status': 'failed',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(failed.isTranscriptionFinal, isTrue);

      final skipped = VoiceMessage.fromMap({
        'id': 'm-2',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'transcription_status': 'skipped',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(skipped.isTranscriptionFinal, isTrue);
    });

    test('isTranscriptionFinal is false for pending and processing', () {
      final pending = VoiceMessage.fromMap({
        'id': 'm-1',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'transcription_status': 'pending',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(pending.isTranscriptionFinal, isFalse);

      final processing = VoiceMessage.fromMap({
        'id': 'm-2',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'transcription_status': 'processing',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(processing.isTranscriptionFinal, isFalse);
    });

    test('senderName defaults to Operador when participant missing', () {
      final msg = VoiceMessage.fromMap({
        'id': 'm-1',
        'event_id': 'ev-1',
        'channel_id': 'ch-1',
        'participant_id': 'p-1',
        'created_at': '2026-06-23T15:00:00Z',
      });
      expect(msg.senderName, 'Operador');
    });
  });

  // -------------------------------------------------------------------------
  // EventLog
  // -------------------------------------------------------------------------

  group('EventLog.fromMap', () {
    test('parses a full map', () {
      final log = EventLog.fromMap({
        'id': 'log-1',
        'event_id': 'ev-1',
        'participant_id': 'p-1',
        'channel_id': 'ch-1',
        'type': 'ptt_sent',
        'title': 'PTT enviado',
        'detail': 'Canal Produccion',
        'created_at': '2026-06-23T15:00:00Z',
      });

      expect(log.id, 'log-1');
      expect(log.type, 'ptt_sent');
      expect(log.title, 'PTT enviado');
      expect(log.detail, 'Canal Produccion');
      expect(log.channelId, 'ch-1');
      expect(log.participantId, 'p-1');
    });

    test('handles null optional fields', () {
      final log = EventLog.fromMap({
        'id': 'log-1',
        'event_id': 'ev-1',
        'type': 'system',
        'title': 'Evento creado',
        'created_at': '2026-06-23T10:00:00Z',
      });

      expect(log.participantId, isNull);
      expect(log.channelId, isNull);
      expect(log.detail, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Enum coverage
  // -------------------------------------------------------------------------

  group('Enum fromValue exhaustive', () {
    test('all EventStatus values round-trip', () {
      for (final status in EventStatus.values) {
        expect(EventStatus.fromValue(status.value), status);
      }
    });

    test('all ParticipantRole values round-trip', () {
      for (final role in ParticipantRole.values) {
        expect(ParticipantRole.fromValue(role.value), role);
      }
    });

    test('all TranscriptionStatus values round-trip', () {
      for (final status in TranscriptionStatus.values) {
        expect(TranscriptionStatus.fromValue(status.value), status);
      }
    });
  });
}
