import 'dart:typed_data';

import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_parser.dart';

class MockEventRadioRepository implements EventRadioRepository {
  MockEventRadioRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  late EventRadioEvent _activeEvent = EventRadioEvent(
    id: 'event-sati-26',
    name: 'CONGRESO OPERACIONES SATI-26',
    description: 'Operativo de comunicaciones para staff en piso.',
    startsAt: _now.subtract(const Duration(hours: 2)),
    endsAt: _now.add(const Duration(hours: 3)),
    status: EventStatus.active,
  );

  late final EventRadioEvent _closedEvent = EventRadioEvent(
    id: 'event-closed',
    name: 'PRUEBA EVENTO FINALIZADO',
    description: 'Caso de prueba para bloqueo operativo.',
    startsAt: _now.subtract(const Duration(hours: 6)),
    endsAt: _now.subtract(const Duration(hours: 1)),
    status: EventStatus.closed,
  );

  late EventParticipant _laura = EventParticipant(
    id: 'participant-laura',
    eventId: _activeEvent.id,
    displayName: 'Laura C.',
    role: ParticipantRole.coordinator,
    inviteCode: 'SATI26',
    inviteStatus: 'accepted',
    joinedAt: _now.subtract(const Duration(minutes: 18)),
  );

  late final EventParticipant _closedParticipant = EventParticipant(
    id: 'participant-closed',
    eventId: _closedEvent.id,
    displayName: 'Operador Demo',
    role: ParticipantRole.participant,
    inviteCode: 'CERRADO',
    inviteStatus: 'accepted',
    joinedAt: _now.subtract(const Duration(hours: 2)),
  );

  late final List<EventChannel> _activeChannels = [
    EventChannel(
      id: 'channel-security',
      eventId: _activeEvent.id,
      name: 'Seguridad interna',
      code: 'seguridad',
      description: 'Control de accesos, rondas y novedades de seguridad.',
      priority: 100,
      isEmergency: true,
      livekitRoomName: 'event_sati26_seguridad',
    ),
    EventChannel(
      id: 'channel-production',
      eventId: _activeEvent.id,
      name: 'Produccion',
      code: 'produccion',
      description: 'Coordinacion general del evento.',
      priority: 70,
      livekitRoomName: 'event_sati26_produccion',
    ),
    EventChannel(
      id: 'channel-tech',
      eventId: _activeEvent.id,
      name: 'Tecnica',
      code: 'tecnica',
      description: 'Audio, luces, escenario y soporte tecnico.',
      priority: 60,
      livekitRoomName: 'event_sati26_tecnica',
    ),
    EventChannel(
      id: 'channel-access',
      eventId: _activeEvent.id,
      name: 'Accesos',
      code: 'accesos',
      description: 'Ingreso de publico, proveedores y acreditaciones.',
      priority: 40,
      livekitRoomName: 'event_sati26_accesos',
    ),
  ];

  late final List<EventParticipant> _activeParticipants = [
    _laura,
    EventParticipant(
      id: 'participant-marcos',
      eventId: _activeEvent.id,
      displayName: 'Marcos',
      phone: '+54 9 264 555-0101',
      role: ParticipantRole.participant,
      inviteCode: 'MARCOS26',
      inviteStatus: 'accepted',
      joinedAt: _now.subtract(const Duration(minutes: 24)),
    ),
    EventParticipant(
      id: 'participant-ana',
      eventId: _activeEvent.id,
      displayName: 'Ana',
      phone: '+54 9 264 555-0102',
      role: ParticipantRole.participant,
      inviteCode: 'ANA26',
      inviteStatus: 'accepted',
      joinedAt: _now.subtract(const Duration(minutes: 22)),
    ),
    EventParticipant(
      id: 'participant-julia',
      eventId: _activeEvent.id,
      displayName: 'Julia',
      phone: '+54 9 264 555-0103',
      role: ParticipantRole.coordinator,
      inviteCode: 'JULIA26',
      inviteStatus: 'pending',
    ),
  ];

  late final List<ChannelPermission> _activePermissions =
      _initialChannelPermissions();

  late final List<VoiceMessage> _messages = [
    VoiceMessage(
      id: 'message-1',
      eventId: _activeEvent.id,
      channelId: 'channel-security',
      participantId: 'participant-marcos',
      senderName: 'Marcos',
      durationSeconds: 6,
      transcription: 'Acceso norte habilitado. Equipo listo en puerta.',
      transcriptionStatus: TranscriptionStatus.completed,
      transcriptionProvider: 'mock',
      transcriptionJobId: 'mock-message-1',
      createdAt: _now.subtract(const Duration(minutes: 23)),
    ),
    VoiceMessage(
      id: 'message-2',
      eventId: _activeEvent.id,
      channelId: 'channel-security',
      participantId: 'participant-ana',
      senderName: 'Ana',
      durationSeconds: 8,
      transcription: 'Revisando zona norte. Todo tranquilo.',
      transcriptionStatus: TranscriptionStatus.completed,
      transcriptionProvider: 'mock',
      transcriptionJobId: 'mock-message-2',
      createdAt: _now.subtract(const Duration(minutes: 19)),
    ),
    VoiceMessage(
      id: 'message-3',
      eventId: _activeEvent.id,
      channelId: 'channel-production',
      participantId: 'participant-laura',
      senderName: 'Laura C.',
      durationSeconds: 5,
      transcription: 'Cierre de puertas en cinco minutos.',
      transcriptionStatus: TranscriptionStatus.completed,
      transcriptionProvider: 'mock',
      transcriptionJobId: 'mock-message-3',
      createdAt: _now.subtract(const Duration(minutes: 12)),
    ),
    VoiceMessage(
      id: 'message-4',
      eventId: _activeEvent.id,
      channelId: 'channel-tech',
      participantId: 'participant-julia',
      senderName: 'Julia',
      durationSeconds: 7,
      transcription: 'Audio confirmado, acceso tres liberado.',
      transcriptionStatus: TranscriptionStatus.completed,
      transcriptionProvider: 'mock',
      transcriptionJobId: 'mock-message-4',
      createdAt: _now.subtract(const Duration(minutes: 9)),
    ),
  ];

  late final List<EventLog> _logs = [
    EventLog(
      id: 'log-1',
      eventId: _activeEvent.id,
      type: 'participant_joined',
      title: 'Laura C. ingreso al evento',
      detail: 'Ingreso validado con codigo SATI26.',
      createdAt: _now.subtract(const Duration(minutes: 18)),
    ),
    EventLog(
      id: 'log-2',
      eventId: _activeEvent.id,
      channelId: 'channel-security',
      type: 'message_sent',
      title: 'Mensaje en Seguridad interna',
      detail: 'Acceso norte habilitado.',
      createdAt: _now.subtract(const Duration(minutes: 14)),
    ),
    EventLog(
      id: 'log-3',
      eventId: _activeEvent.id,
      channelId: 'channel-tech',
      type: 'system_notice',
      title: 'Chequeo tecnico confirmado',
      detail: 'Audio y luces reportados como listos.',
      createdAt: _now.subtract(const Duration(minutes: 8)),
    ),
  ];

  @override
  Future<EventSession> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final normalized = InviteCodeParser.fromQrValue(code);

    EventParticipant? activeParticipant;
    for (final participant in _activeParticipants) {
      if (participant.inviteCode == normalized) {
        activeParticipant = participant;
        break;
      }
    }
    if (activeParticipant != null) {
      return _activeSessionFor(activeParticipant);
    }

    if (normalized == _closedParticipant.inviteCode) {
      return EventSession(
        event: _closedEvent,
        participant: _closedParticipant,
        channels: [
          EventChannel(
            id: 'channel-closed-production',
            eventId: _closedEvent.id,
            name: 'Produccion',
            code: 'produccion',
            priority: 50,
            livekitRoomName: 'event_closed_produccion',
          ),
        ],
        permissions: [
          ChannelPermission(
            channelId: 'channel-closed-production',
            participantId: _closedParticipant.id,
            canTalk: false,
          ),
        ],
      );
    }

    throw const JoinEventException(JoinErrorCode.codeNotFound);
  }

  @override
  Future<EventSession> refreshSession(EventSession session) async {
    return _activeSessionFrom(session);
  }

  EventSession _activeSessionFor(EventParticipant participant) {
    return EventSession(
      event: _activeEvent,
      participant: participant,
      channels: _visibleChannelsFor(participant),
      permissions: _permissionsFor(participant),
      participants: [..._activeParticipants],
      allPermissions: [..._activePermissions],
    );
  }

  EventSession _activeSessionFrom(EventSession session) {
    final participant =
        _activeParticipantById(session.participant.id) ?? _laura;
    return _activeSessionFor(participant);
  }

  EventParticipant? _activeParticipantById(String id) {
    for (final participant in _activeParticipants) {
      if (participant.id == id) return participant;
    }
    return null;
  }

  List<ChannelPermission> _permissionsFor(EventParticipant participant) {
    return _activePermissions
        .where((permission) => permission.participantId == participant.id)
        .toList();
  }

  List<EventChannel> _visibleChannelsFor(EventParticipant participant) {
    final visibleChannelIds = _permissionsFor(participant)
        .where((permission) => permission.canListen)
        .map((permission) => permission.channelId)
        .toSet();
    return _activeChannels
        .where((channel) => visibleChannelIds.contains(channel.id))
        .toList();
  }

  List<ChannelPermission> _initialChannelPermissions() {
    ChannelPermission permissionFor(
      EventParticipant participant,
      EventChannel channel, {
      bool canTalk = true,
    }) {
      return ChannelPermission(
        channelId: channel.id,
        participantId: participant.id,
        canTalk: canTalk && participant.role != ParticipantRole.viewer,
      );
    }

    final security = _activeChannels.firstWhere(
      (channel) => channel.id == 'channel-security',
    );
    final production = _activeChannels.firstWhere(
      (channel) => channel.id == 'channel-production',
    );
    final tech = _activeChannels.firstWhere(
      (channel) => channel.id == 'channel-tech',
    );
    final access = _activeChannels.firstWhere(
      (channel) => channel.id == 'channel-access',
    );
    final marcos = _activeParticipants.firstWhere(
      (participant) => participant.id == 'participant-marcos',
    );
    final ana = _activeParticipants.firstWhere(
      (participant) => participant.id == 'participant-ana',
    );
    final julia = _activeParticipants.firstWhere(
      (participant) => participant.id == 'participant-julia',
    );

    return [
      for (final channel in _activeChannels)
        permissionFor(
          _laura,
          channel,
          canTalk: !channel.code.contains('accesos'),
        ),
      permissionFor(marcos, security),
      permissionFor(marcos, access),
      permissionFor(ana, security, canTalk: false),
      permissionFor(ana, access),
      for (final channel in [security, production, tech])
        permissionFor(julia, channel),
    ];
  }

  @override
  Future<List<EventLog>> getEventLogs(String eventId) async {
    return _logs.where((log) => log.eventId == eventId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<VoiceMessage>> getVoiceMessages(String channelId) async {
    return _messages.where((message) => message.channelId == channelId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<String?> getVoiceMessageAudioUrl(VoiceMessage message) async {
    return message.audioUrl;
  }

  @override
  Future<int> transcribePendingMessages(
    String channelId, {
    List<String> messageIds = const [],
    int? limit,
  }) async {
    final targetIds =
        messageIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    var count = 0;
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (message.channelId != channelId ||
          message.transcriptionStatus != TranscriptionStatus.pending ||
          (targetIds.isNotEmpty && !targetIds.contains(message.id))) {
        continue;
      }
      _messages[index] = VoiceMessage(
        id: message.id,
        eventId: message.eventId,
        channelId: message.channelId,
        participantId: message.participantId,
        senderName: message.senderName,
        audioUrl: message.audioUrl,
        storagePath: message.storagePath,
        durationSeconds: message.durationSeconds,
        transcription:
            'Transcripcion mock: mensaje recibido de ${message.senderName}.',
        transcriptionStatus: TranscriptionStatus.completed,
        transcriptionProvider: 'mock',
        transcriptionJobId: 'mock-transcription-${message.id}',
        isPriority: message.isPriority,
        createdAt: message.createdAt,
      );
      count++;
      if (limit != null && count >= limit) break;
    }
    return count;
  }

  @override
  Future<List<VoiceMessage>> sendPttMessage({
    required EventSession session,
    required List<EventChannel> channels,
    required int durationSeconds,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? browserTranscriptionText,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    final isBroadcast = channels.length > 1;
    final messages = <VoiceMessage>[];
    final browserTranscript = browserTranscriptionText?.trim();
    final hasBrowserTranscript =
        browserTranscript != null && browserTranscript.isNotEmpty;
    final hasRecordedAudio = audioBytes != null && audioBytes.isNotEmpty;

    for (final (index, channel) in channels.indexed) {
      final message = VoiceMessage(
        id: 'message-${now.microsecondsSinceEpoch}-$index',
        eventId: session.event.id,
        channelId: channel.id,
        participantId: session.participant.id,
        senderName: session.participant.displayName,
        audioUrl: hasRecordedAudio
            ? 'mock://audio/${now.microsecondsSinceEpoch}-$index.wav'
            : null,
        durationSeconds: durationSeconds.toDouble(),
        transcription: hasBrowserTranscript
            ? browserTranscript
            : hasRecordedAudio
                ? null
                : _mockTranscription(channel, isBroadcast: isBroadcast),
        transcriptionStatus: hasRecordedAudio && !hasBrowserTranscript
            ? TranscriptionStatus.pending
            : TranscriptionStatus.completed,
        transcriptionProvider: hasBrowserTranscript
            ? 'browser_speech'
            : hasRecordedAudio
                ? null
                : 'mock',
        transcriptionJobId: hasRecordedAudio && !hasBrowserTranscript
            ? null
            : 'mock-${now.microsecondsSinceEpoch}-$index',
        isPriority: channel.isEmergency || isBroadcast,
        createdAt: now,
      );

      messages.add(message);
      _messages.add(message);
    }

    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: session.event.id,
        participantId: session.participant.id,
        channelId: isBroadcast ? null : channels.first.id,
        type: isBroadcast
            ? 'broadcast_message'
            : channels.first.isEmergency
                ? 'emergency_message'
                : 'message_sent',
        title: isBroadcast
            ? 'Broadcast enviado a ${channels.length} canales'
            : 'PTT enviado en ${channels.first.name}',
        detail: messages.first.transcription,
        createdAt: now,
      ),
    );

    return messages;
  }

  @override
  Future<VoiceMessage> sendSosAlert({
    required EventSession session,
    required EventChannel channel,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _ensureCanSendSos(session: session, channel: channel);

    final now = DateTime.now();
    final message = VoiceMessage(
      id: 'message-sos-${now.microsecondsSinceEpoch}',
      eventId: session.event.id,
      channelId: channel.id,
      participantId: session.participant.id,
      senderName: session.participant.displayName,
      durationSeconds: 0,
      transcription: 'SOS activado en ${channel.name}. Prioridad maxima.',
      transcriptionStatus: TranscriptionStatus.completed,
      isPriority: true,
      createdAt: now,
    );

    _messages.add(message);
    _logs.add(
      EventLog(
        id: 'log-sos-${now.microsecondsSinceEpoch}',
        eventId: session.event.id,
        participantId: session.participant.id,
        channelId: channel.id,
        type: 'emergency_message',
        title: 'SOS activado en ${channel.name}',
        detail: message.transcription,
        createdAt: now,
      ),
    );

    return message;
  }

  void _ensureCanSendSos({
    required EventSession session,
    required EventChannel channel,
  }) {
    if (!session.event.isOperational(_now)) {
      throw const EventOperationException(
        EventOperationErrorCode.eventNotOperational,
      );
    }
    final permission = session.permissionFor(channel.id);
    if (permission == null || !permission.canListen || !permission.canTalk) {
      throw const EventOperationException(
        EventOperationErrorCode.insufficientPermission,
      );
    }
  }

  String _mockTranscription(
    EventChannel channel, {
    required bool isBroadcast,
  }) {
    if (isBroadcast) {
      return 'Broadcast general: coordinacion informa novedad operativa para todos los canales.';
    }

    if (channel.isEmergency) {
      return 'Mensaje prioritario recibido. Equipo atento en ${channel.name}.';
    }

    return switch (channel.code) {
      'produccion' => 'Coordinacion confirma avance de operacion.',
      'tecnica' => 'Chequeo tecnico recibido y en seguimiento.',
      'accesos' => 'Novedad registrada en accesos.',
      _ => 'Mensaje PTT simulado recibido correctamente.',
    };
  }

  @override
  Future<EventSession> updateEventDetails({
    required EventSession session,
    required String name,
    required String description,
    required EventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    _activeEvent = _activeEvent.copyWith(
      name: name.trim(),
      description: description.trim(),
      status: status,
      startsAt: startsAt,
      endsAt: endsAt,
    );

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'event_updated',
        title: 'Evento actualizado',
        detail: _activeEvent.name,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> createEvent({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final now = DateTime.now();
    _activeEvent = EventRadioEvent(
      id: 'event-${now.microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      status: EventStatus.active,
    );
    _laura = EventParticipant(
      id: 'participant-laura',
      eventId: _activeEvent.id,
      displayName: 'Laura C.',
      role: ParticipantRole.coordinator,
      inviteCode: 'SATI26',
      inviteStatus: 'accepted',
      joinedAt: now,
    );

    _activeChannels
      ..clear()
      ..add(
        EventChannel(
          id: 'channel-${now.microsecondsSinceEpoch}',
          eventId: _activeEvent.id,
          name: 'Produccion',
          code: 'produccion',
          description: 'Coordinacion general del evento.',
          priority: 70,
          livekitRoomName: 'event_${now.microsecondsSinceEpoch}_produccion',
        ),
      );
    _activeParticipants
      ..clear()
      ..add(_laura);
    _activePermissions
      ..clear()
      ..add(
        ChannelPermission(
          channelId: _activeChannels.first.id,
          participantId: _laura.id,
        ),
      );
    _messages.clear();

    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'event_created',
        title: 'Evento mock creado',
        detail: _activeEvent.name,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> createChannel({
    required EventSession session,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  }) async {
    final normalizedCode = _normalizeCode(code);
    if (name.trim().isEmpty) {
      throw ArgumentError('El nombre del canal es obligatorio.');
    }
    if (normalizedCode.isEmpty) {
      throw ArgumentError('El codigo del canal es obligatorio.');
    }
    if (_channelCodeExists(normalizedCode)) {
      throw ArgumentError('El codigo del canal ya existe.');
    }
    final now = DateTime.now();
    final channel = EventChannel(
      id: 'channel-${now.microsecondsSinceEpoch}',
      eventId: _activeEvent.id,
      name: name.trim(),
      code: normalizedCode,
      description: description.trim(),
      priority: priority.clamp(0, 100),
      isEmergency: isEmergency,
      livekitRoomName: 'event_sati26_$normalizedCode',
    );

    _activeChannels.add(channel);
    _activePermissions.add(
      ChannelPermission(
        channelId: channel.id,
        participantId: _laura.id,
        canTalk: true,
      ),
    );
    for (final participant in _activeParticipants) {
      if (participant.id == _laura.id || !participant.canAccessAdmin) continue;
      _activePermissions.add(
        ChannelPermission(
          channelId: channel.id,
          participantId: participant.id,
          canTalk: true,
        ),
      );
    }
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        channelId: channel.id,
        type: 'channel_created',
        title: 'Canal creado: ${channel.name}',
        detail: channel.description,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> updateChannel({
    required EventSession session,
    required EventChannel channel,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  }) async {
    final index = _activeChannels.indexWhere((item) => item.id == channel.id);
    if (index == -1) return _activeSessionFrom(session);

    final normalizedCode = _normalizeCode(code);
    if (name.trim().isEmpty) {
      throw ArgumentError('El nombre del canal es obligatorio.');
    }
    if (normalizedCode.isEmpty) {
      throw ArgumentError('El codigo del canal es obligatorio.');
    }
    if (_channelCodeExists(normalizedCode, exceptChannelId: channel.id)) {
      throw ArgumentError('El codigo del canal ya existe.');
    }

    final updated = channel.copyWith(
      name: name.trim(),
      code: normalizedCode,
      description: description.trim(),
      priority: priority.clamp(0, 100),
      isEmergency: isEmergency,
    );
    _activeChannels[index] = updated;

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        channelId: updated.id,
        type: 'channel_updated',
        title: 'Canal actualizado: ${updated.name}',
        detail: updated.description,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  }) async {
    if (_activeChannels.length <= 1) return _activeSessionFrom(session);

    final index = _activeChannels.indexWhere((item) => item.id == channel.id);
    if (index == -1) return _activeSessionFrom(session);
    _activeChannels.removeAt(index);

    _activePermissions.removeWhere(
      (permission) => permission.channelId == channel.id,
    );
    _messages.removeWhere((message) => message.channelId == channel.id);

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        channelId: channel.id,
        type: 'channel_deleted',
        title: 'Canal eliminado: ${channel.name}',
        detail: channel.code,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    final normalizedInviteCode = _normalizeInviteCode(inviteCode);
    if (displayName.trim().isEmpty) {
      throw ArgumentError('El nombre del participante es obligatorio.');
    }
    if (normalizedInviteCode.isEmpty) {
      throw ArgumentError('El codigo de invitacion es obligatorio.');
    }
    if (_inviteCodeExists(normalizedInviteCode)) {
      throw ArgumentError('El codigo de invitacion ya existe.');
    }
    final now = DateTime.now();
    final participant = EventParticipant(
      id: 'participant-${now.microsecondsSinceEpoch}',
      eventId: _activeEvent.id,
      displayName: displayName.trim(),
      phone: phone.trim(),
      role: role,
      inviteCode: normalizedInviteCode,
      inviteStatus: 'pending',
    );

    _activeParticipants.add(participant);
    _activePermissions.addAll(
      _activeChannels.map(
        (channel) => ChannelPermission(
          channelId: channel.id,
          participantId: participant.id,
          canTalk: role != ParticipantRole.viewer,
        ),
      ),
    );
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'participant_invited',
        title: 'Participante invitado: ${participant.displayName}',
        detail: participant.inviteCode,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> updateParticipant({
    required EventSession session,
    required EventParticipant participant,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    final index =
        _activeParticipants.indexWhere((item) => item.id == participant.id);
    if (index == -1) return _activeSessionFrom(session);

    final normalizedInviteCode = _normalizeInviteCode(inviteCode);
    if (displayName.trim().isEmpty) {
      throw ArgumentError('El nombre del participante es obligatorio.');
    }
    if (normalizedInviteCode.isEmpty) {
      throw ArgumentError('El codigo de invitacion es obligatorio.');
    }
    if (_inviteCodeExists(
      normalizedInviteCode,
      exceptParticipantId: participant.id,
    )) {
      throw ArgumentError('El codigo de invitacion ya existe.');
    }

    final updated = participant.copyWith(
      displayName: displayName.trim(),
      phone: phone.trim(),
      role: role,
      inviteCode: normalizedInviteCode,
    );
    _activeParticipants[index] = updated;
    if (participant.id == _laura.id) {
      _laura = updated;
    }
    if (updated.role == ParticipantRole.viewer) {
      for (var i = 0; i < _activePermissions.length; i++) {
        final permission = _activePermissions[i];
        if (permission.participantId == updated.id) {
          _activePermissions[i] = permission.copyWith(canTalk: false);
        }
      }
    }

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'participant_updated',
        title: 'Participante actualizado: ${updated.displayName}',
        detail: updated.role.value,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  }) async {
    if (participant.id == session.participant.id) {
      return _activeSessionFrom(session);
    }

    final index =
        _activeParticipants.indexWhere((item) => item.id == participant.id);
    if (index == -1) return _activeSessionFrom(session);
    _activeParticipants.removeAt(index);

    _activePermissions.removeWhere(
      (permission) => permission.participantId == participant.id,
    );

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'participant_deleted',
        title: 'Participante eliminado: ${participant.displayName}',
        detail: participant.inviteCode,
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  @override
  Future<EventSession> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  }) async {
    _activePermissions.removeWhere(
      (permission) => permission.participantId == participant.id,
    );
    final participantRole =
        _activeParticipantById(participant.id)?.role ?? participant.role;
    _activePermissions.addAll(
      permissions.where((permission) => permission.canListen).map(
            (permission) => ChannelPermission(
              channelId: permission.channelId,
              participantId: participant.id,
              canTalk: permission.canTalk &&
                  participantRole != ParticipantRole.viewer,
              canViewHistory: permission.canViewHistory,
            ),
          ),
    );

    final now = DateTime.now();
    _logs.add(
      EventLog(
        id: 'log-${now.microsecondsSinceEpoch}',
        eventId: _activeEvent.id,
        participantId: session.participant.id,
        type: 'participant_channels_updated',
        title: 'Canales actualizados: ${participant.displayName}',
        detail: '${permissions.where((item) => item.canListen).length} canales',
        createdAt: now,
      ),
    );

    return _activeSessionFrom(session);
  }

  String _normalizeCode(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _normalizeInviteCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  bool _channelCodeExists(String code, {String? exceptChannelId}) {
    return _activeChannels.any(
      (channel) => channel.id != exceptChannelId && channel.code == code,
    );
  }

  bool _inviteCodeExists(String inviteCode, {String? exceptParticipantId}) {
    final activeCodeExists = _activeParticipants.any(
      (participant) =>
          participant.id != exceptParticipantId &&
          participant.inviteCode == inviteCode,
    );
    return activeCodeExists || _closedParticipant.inviteCode == inviteCode;
  }
}
