import 'dart:typed_data';

import 'package:event_radio_app/src/shared/data/mock_event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEventRadioRepository repository;

  setUp(() {
    repository = MockEventRadioRepository(
      now: DateTime(2026, 6, 23, 12),
    );
  });

  test('joins active demo event by code', () async {
    final session = await repository.joinByCode('sati26');

    expect(session.event.name, contains('SATI-26'));
    expect(session.orderedChannels.first.name, 'Seguridad interna');
    expect(session.event.isOperational(DateTime(2026, 6, 23, 12)), isTrue);
  });

  test('throws a friendly exception for invalid code', () async {
    expect(
      () => repository.joinByCode('MAL'),
      throwsA(isA<JoinEventException>()),
    );
  });

  test('returns messages filtered by channel', () async {
    final messages = await repository.getVoiceMessages('channel-security');

    expect(messages, isNotEmpty);
    expect(
      messages.every((message) => message.channelId == 'channel-security'),
      isTrue,
    );
  });

  test('stores a simulated PTT message and event log', () async {
    final session = await repository.joinByCode('SATI26');
    final channel = session.channelById('channel-production')!;

    final sentMessages = await repository.sendPttMessage(
      session: session,
      channels: [channel],
      durationSeconds: 3,
    );
    final message = sentMessages.single;

    final messages = await repository.getVoiceMessages(channel.id);
    final logs = await repository.getEventLogs(session.event.id);

    expect(message.senderName, 'Laura C.');
    expect(messages.any((item) => item.id == message.id), isTrue);
    expect(message.transcription, contains('Coordinacion'));
    expect(logs.any((log) => log.title == 'PTT enviado en Produccion'), isTrue);
  });

  test('stores broadcast PTT messages in every target channel', () async {
    final session = await repository.joinByCode('SATI26');

    final sentMessages = await repository.sendPttMessage(
      session: session,
      channels: session.channels,
      durationSeconds: 4,
    );

    final securityMessages =
        await repository.getVoiceMessages('channel-security');
    final productionMessages =
        await repository.getVoiceMessages('channel-production');
    final logs = await repository.getEventLogs(session.event.id);

    expect(sentMessages, hasLength(session.channels.length));
    expect(
      securityMessages.any((message) => message.id == sentMessages.first.id),
      isTrue,
    );
    expect(
      productionMessages.any(
        (message) =>
            message.transcription?.contains('Broadcast general') ?? false,
      ),
      isTrue,
    );
    expect(
      logs.any((log) => log.title == 'Broadcast enviado a 4 canales'),
      isTrue,
    );
  });

  test('transcribes pending recorded audio by message id', () async {
    final session = await repository.joinByCode('SATI26');
    final channel = session.channelById('channel-production')!;

    final sentMessages = await repository.sendPttMessage(
      session: session,
      channels: [channel],
      durationSeconds: 3,
      audioBytes: Uint8List.fromList([1, 2, 3]),
      audioMimeType: 'audio/wav',
    );
    final pendingMessage = sentMessages.single;

    expect(pendingMessage.hasAudio, isTrue);
    expect(pendingMessage.transcriptionStatus, TranscriptionStatus.pending);

    final count = await repository.transcribePendingMessages(
      channel.id,
      messageIds: [pendingMessage.id],
    );
    final messages = await repository.getVoiceMessages(channel.id);
    final transcribed =
        messages.firstWhere((message) => message.id == pendingMessage.id);

    expect(count, 1);
    expect(transcribed.transcriptionStatus, TranscriptionStatus.completed);
    expect(transcribed.transcription, contains('Transcripcion mock'));
  });

  test('stores SOS as a priority message and event log', () async {
    final session = await repository.joinByCode('SATI26');
    final channel = session.channelById('channel-security')!;

    final message = await repository.sendSosAlert(
      session: session,
      channel: channel,
    );

    final messages = await repository.getVoiceMessages(channel.id);
    final logs = await repository.getEventLogs(session.event.id);

    expect(message.isPriority, isTrue);
    expect(message.durationSeconds, 0);
    expect(message.transcription, contains('SOS activado'));
    expect(messages.first.id, message.id);
    expect(
      logs.any(
        (log) =>
            log.type == 'emergency_message' &&
            log.title == 'SOS activado en Seguridad interna',
      ),
      isTrue,
    );
  });

  test('blocks SOS when event is closed or participant cannot talk', () async {
    final closedSession = await repository.joinByCode('CERRADO');
    final closedChannel = closedSession.channels.single;

    expect(
      () => repository.sendSosAlert(
        session: closedSession,
        channel: closedChannel,
      ),
      throwsStateError,
    );

    final anaSession = await repository.joinByCode('ANA26');
    final security = anaSession.channelById('channel-security')!;

    expect(
      () => repository.sendSosAlert(
        session: anaSession,
        channel: security,
      ),
      throwsStateError,
    );
  });

  test('filters channels by participant assignments', () async {
    final marcosSession = await repository.joinByCode('MARCOS26');

    expect(
      marcosSession.orderedChannels.map((channel) => channel.code),
      ['seguridad', 'accesos'],
    );
    expect(marcosSession.channelById('channel-production'), isNull);

    final adminSession = await repository.joinByCode('SATI26');
    final marcos = adminSession.participants.firstWhere(
      (participant) => participant.inviteCode == 'MARCOS26',
    );
    await repository.updateParticipantChannels(
      session: adminSession,
      participant: marcos,
      permissions: [
        const ChannelPermission(
          channelId: 'channel-production',
          participantId: 'participant-marcos',
          canTalk: false,
        ),
      ],
    );

    final updatedMarcosSession = await repository.joinByCode('MARCOS26');

    expect(updatedMarcosSession.channels, hasLength(1));
    expect(updatedMarcosSession.channels.single.code, 'produccion');
    expect(
      updatedMarcosSession.permissionFor('channel-production')?.canTalk,
      isFalse,
    );
  });

  test('updates event details and creates a new mock event', () async {
    final session = await repository.joinByCode('SATI26');
    final updatedStartsAt = DateTime(2026, 6, 24, 8, 30);
    final updatedEndsAt = DateTime(2026, 6, 24, 12);

    final updated = await repository.updateEventDetails(
      session: session,
      name: 'Operativo actualizado',
      description: 'Nueva descripcion',
      status: EventStatus.scheduled,
      startsAt: updatedStartsAt,
      endsAt: updatedEndsAt,
    );

    expect(updated.event.name, 'Operativo actualizado');
    expect(updated.event.status, EventStatus.scheduled);
    expect(updated.event.startsAt, updatedStartsAt);
    expect(updated.event.endsAt, updatedEndsAt);

    final created = await repository.createEvent(
      session: updated,
      name: 'Nuevo show',
      description: 'Nuevo evento mock',
      startsAt: DateTime(2026, 7, 1, 18),
      endsAt: DateTime(2026, 7, 1, 23, 30),
    );

    expect(created.event.name, 'Nuevo show');
    expect(created.event.startsAt, DateTime(2026, 7, 1, 18));
    expect(created.event.endsAt, DateTime(2026, 7, 1, 23, 30));
    expect(created.channels, hasLength(1));
    expect(created.participants, hasLength(1));
  });

  test('creates and edits channels', () async {
    final session = await repository.joinByCode('SATI26');

    final withChannel = await repository.createChannel(
      session: session,
      name: 'Prensa',
      code: 'Prensa VIP',
      description: 'Equipo de prensa',
      priority: 35,
      isEmergency: false,
    );

    final created = withChannel.channels.firstWhere(
      (channel) => channel.code == 'prensa-vip',
    );
    expect(created.name, 'Prensa');

    final edited = await repository.updateChannel(
      session: withChannel,
      channel: created,
      name: 'Prensa general',
      code: 'prensa',
      description: 'Prensa y comunicacion',
      priority: 45,
      isEmergency: false,
    );

    expect(edited.channelById(created.id)?.name, 'Prensa general');
    expect(edited.channelById(created.id)?.priority, 45);

    final withoutChannel = await repository.deleteChannel(
      session: edited,
      channel: edited.channelById(created.id)!,
    );

    expect(withoutChannel.channelById(created.id), isNull);
    expect(
      withoutChannel.allPermissions.any(
        (permission) => permission.channelId == created.id,
      ),
      isFalse,
    );
  });

  test('rejects empty and duplicate channel codes', () async {
    final session = await repository.joinByCode('SATI26');

    expect(
      () => repository.createChannel(
        session: session,
        name: 'Prensa',
        code: '',
        description: 'Equipo de prensa',
        priority: 35,
        isEmergency: false,
      ),
      throwsArgumentError,
    );

    expect(
      () => repository.createChannel(
        session: session,
        name: 'Produccion duplicada',
        code: 'produccion',
        description: 'Codigo repetido',
        priority: 35,
        isEmergency: false,
      ),
      throwsArgumentError,
    );
  });

  test('creates and edits participants with invite codes', () async {
    final session = await repository.joinByCode('SATI26');

    final withParticipant = await repository.createParticipant(
      session: session,
      displayName: 'Sofia',
      phone: '+54 9 264 555-0199',
      role: ParticipantRole.viewer,
      inviteCode: 'sofia 26',
    );

    final created = withParticipant.participants.firstWhere(
      (participant) => participant.inviteCode == 'SOFIA26',
    );
    expect(created.role, ParticipantRole.viewer);

    final joined = await repository.joinByCode('SOFIA26');
    expect(joined.participant.displayName, 'Sofia');
    expect(joined.channels, hasLength(withParticipant.channels.length));
    expect(
        joined.permissions.every((permission) => !permission.canTalk), isTrue);

    final edited = await repository.updateParticipant(
      session: withParticipant,
      participant: created,
      displayName: 'Sofia M.',
      phone: '+54 9 264 555-0200',
      role: ParticipantRole.participant,
      inviteCode: 'sofia radio',
    );

    expect(
      edited.participants
          .firstWhere((participant) => participant.id == created.id)
          .inviteCode,
      'SOFIARADIO',
    );

    final deleted = await repository.deleteParticipant(
      session: edited,
      participant: edited.participants.firstWhere(
        (participant) => participant.id == created.id,
      ),
    );

    expect(
      deleted.participants.any((participant) => participant.id == created.id),
      isFalse,
    );
    expect(
      () => repository.joinByCode('SOFIARADIO'),
      throwsA(isA<JoinEventException>()),
    );
  });

  test('rejects empty and duplicate participant invite codes', () async {
    final session = await repository.joinByCode('SATI26');

    expect(
      () => repository.createParticipant(
        session: session,
        displayName: 'Sofia',
        phone: '+54 9 264 555-0199',
        role: ParticipantRole.viewer,
        inviteCode: '',
      ),
      throwsArgumentError,
    );

    expect(
      () => repository.createParticipant(
        session: session,
        displayName: 'Sati duplicada',
        phone: '+54 9 264 555-0100',
        role: ParticipantRole.coordinator,
        inviteCode: 'SATI26',
      ),
      throwsArgumentError,
    );
  });
}
