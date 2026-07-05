enum EventStatus {
  draft('draft'),
  scheduled('scheduled'),
  active('active'),
  closed('closed'),
  cancelled('cancelled');

  const EventStatus(this.value);

  final String value;

  static EventStatus fromValue(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => EventStatus.draft,
    );
  }
}

enum ParticipantRole {
  admin('admin'),
  coordinator('coordinator'),
  participant('participant'),
  viewer('viewer');

  const ParticipantRole(this.value);

  final String value;

  static ParticipantRole fromValue(String value) {
    return ParticipantRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ParticipantRole.participant,
    );
  }
}

enum TranscriptionStatus {
  pending('pending'),
  queued('queued'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  skipped('skipped');

  const TranscriptionStatus(this.value);

  final String value;

  static TranscriptionStatus fromValue(String value) {
    return TranscriptionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TranscriptionStatus.pending,
    );
  }
}

class EventRadioEvent {
  const EventRadioEvent({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.description,
    this.createdBy,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final EventStatus status;
  final String? createdBy;

  bool isOperational(DateTime now) {
    return status == EventStatus.active &&
        !now.isBefore(startsAt) &&
        now.isBefore(endsAt);
  }

  bool get isClosed =>
      status == EventStatus.closed || status == EventStatus.cancelled;

  EventRadioEvent copyWith({
    String? name,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    EventStatus? status,
    String? createdBy,
  }) {
    return EventRadioEvent(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory EventRadioEvent.fromMap(Map<String, dynamic> map) {
    return EventRadioEvent(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
      status: EventStatus.fromValue(map['status'] as String? ?? 'draft'),
      createdBy: map['created_by'] as String?,
    );
  }
}

class EventChannel {
  const EventChannel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.code,
    required this.livekitRoomName,
    this.description,
    this.priority = 0,
    this.isEmergency = false,
  });

  final String id;
  final String eventId;
  final String name;
  final String code;
  final String? description;
  final int priority;
  final bool isEmergency;
  final String livekitRoomName;

  EventChannel copyWith({
    String? name,
    String? code,
    String? description,
    int? priority,
    bool? isEmergency,
    String? livekitRoomName,
  }) {
    return EventChannel(
      id: id,
      eventId: eventId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isEmergency: isEmergency ?? this.isEmergency,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
    );
  }

  factory EventChannel.fromMap(Map<String, dynamic> map) {
    return EventChannel(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      priority: map['priority'] as int? ?? 0,
      isEmergency: map['is_emergency'] as bool? ?? false,
      livekitRoomName: map['livekit_room_name'] as String,
    );
  }
}

class EventParticipant {
  const EventParticipant({
    required this.id,
    required this.eventId,
    required this.displayName,
    required this.role,
    required this.inviteCode,
    required this.inviteStatus,
    this.authUserId,
    this.phone,
    this.joinedAt,
  });

  final String id;
  final String eventId;
  final String? authUserId;
  final String displayName;
  final String? phone;
  final ParticipantRole role;
  final String inviteCode;
  final String inviteStatus;
  final DateTime? joinedAt;

  bool get canAccessAdmin =>
      role == ParticipantRole.admin || role == ParticipantRole.coordinator;

  EventParticipant copyWith({
    String? displayName,
    String? phone,
    ParticipantRole? role,
    String? inviteCode,
    String? inviteStatus,
    DateTime? joinedAt,
  }) {
    return EventParticipant(
      id: id,
      eventId: eventId,
      authUserId: authUserId,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory EventParticipant.fromMap(Map<String, dynamic> map) {
    return EventParticipant(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      authUserId: map['auth_user_id'] as String?,
      displayName: map['display_name'] as String,
      phone: map['phone'] as String?,
      role: ParticipantRole.fromValue(map['role'] as String? ?? 'participant'),
      inviteCode: map['invite_code'] as String,
      inviteStatus: map['invite_status'] as String? ?? 'pending',
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.parse(map['joined_at'] as String).toLocal(),
    );
  }
}

class ChannelPermission {
  const ChannelPermission({
    required this.channelId,
    required this.participantId,
    this.canListen = true,
    this.canTalk = true,
    this.canViewHistory = true,
  });

  final String channelId;
  final String participantId;
  final bool canListen;
  final bool canTalk;
  final bool canViewHistory;

  ChannelPermission copyWith({
    bool? canListen,
    bool? canTalk,
    bool? canViewHistory,
  }) {
    return ChannelPermission(
      channelId: channelId,
      participantId: participantId,
      canListen: canListen ?? this.canListen,
      canTalk: canTalk ?? this.canTalk,
      canViewHistory: canViewHistory ?? this.canViewHistory,
    );
  }
}

class VoiceMessage {
  const VoiceMessage({
    required this.id,
    required this.eventId,
    required this.channelId,
    required this.participantId,
    required this.senderName,
    required this.createdAt,
    String? transcription,
    String? transcriptionText,
    this.audioUrl,
    this.storagePath,
    this.durationSeconds,
    this.transcriptionStatus = TranscriptionStatus.pending,
    this.transcriptionProvider,
    this.transcriptionJobId,
    this.isPriority = false,
  }) : transcriptionText = transcriptionText ?? transcription;

  final String id;
  final String eventId;
  final String channelId;
  final String participantId;
  final String senderName;
  final String? audioUrl;
  final String? storagePath;
  final double? durationSeconds;
  final String? transcriptionText;
  final TranscriptionStatus transcriptionStatus;
  final String? transcriptionProvider;
  final String? transcriptionJobId;
  final bool isPriority;
  final DateTime createdAt;

  String? get transcription => transcriptionText;

  bool get hasAudio => audioUrl != null || storagePath != null;

  bool get isTranscriptionFinal =>
      transcriptionStatus == TranscriptionStatus.completed ||
      transcriptionStatus == TranscriptionStatus.failed ||
      transcriptionStatus == TranscriptionStatus.skipped;

  factory VoiceMessage.fromMap(Map<String, dynamic> map) {
    final participant = map['event_participants'] as Map<String, dynamic>?;

    return VoiceMessage(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      channelId: map['channel_id'] as String,
      participantId: map['participant_id'] as String,
      senderName: participant?['display_name'] as String? ?? 'Operador',
      audioUrl: map['audio_url'] as String?,
      storagePath: map['storage_path'] as String?,
      durationSeconds: (map['duration_seconds'] as num?)?.toDouble(),
      transcriptionText: (map['transcription_text'] as String?) ??
          (map['transcription'] as String?),
      transcriptionStatus: TranscriptionStatus.fromValue(
        map['transcription_status'] as String? ?? 'pending',
      ),
      transcriptionProvider: map['transcription_provider'] as String?,
      transcriptionJobId: map['transcription_job_id'] as String?,
      isPriority: map['is_priority'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

class EventLog {
  const EventLog({
    required this.id,
    required this.eventId,
    required this.type,
    required this.title,
    required this.createdAt,
    this.detail,
    this.channelId,
    this.participantId,
  });

  final String id;
  final String eventId;
  final String? participantId;
  final String? channelId;
  final String type;
  final String title;
  final String? detail;
  final DateTime createdAt;

  factory EventLog.fromMap(Map<String, dynamic> map) {
    return EventLog(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      participantId: map['participant_id'] as String?,
      channelId: map['channel_id'] as String?,
      type: map['type'] as String,
      title: map['title'] as String,
      detail: map['detail'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}

class EventSession {
  const EventSession({
    required this.event,
    required this.participant,
    required this.channels,
    required this.permissions,
    this.participants = const [],
    this.allPermissions = const [],
  });

  final EventRadioEvent event;
  final EventParticipant participant;
  final List<EventChannel> channels;
  final List<ChannelPermission> permissions;
  final List<EventParticipant> participants;
  final List<ChannelPermission> allPermissions;

  EventSession copyWith({
    EventRadioEvent? event,
    EventParticipant? participant,
    List<EventChannel>? channels,
    List<ChannelPermission>? permissions,
    List<EventParticipant>? participants,
    List<ChannelPermission>? allPermissions,
  }) {
    return EventSession(
      event: event ?? this.event,
      participant: participant ?? this.participant,
      channels: channels ?? this.channels,
      permissions: permissions ?? this.permissions,
      participants: participants ?? this.participants,
      allPermissions: allPermissions ?? this.allPermissions,
    );
  }

  List<EventChannel> get orderedChannels {
    final ordered = [...channels];
    ordered.sort((a, b) => b.priority.compareTo(a.priority));
    return ordered;
  }

  EventChannel? channelById(String id) {
    for (final channel in channels) {
      if (channel.id == id) return channel;
    }
    return null;
  }

  ChannelPermission? permissionFor(String channelId) {
    for (final permission in permissions) {
      if (permission.channelId == channelId) return permission;
    }
    return null;
  }

  ChannelPermission? permissionForParticipant({
    required String participantId,
    required String channelId,
  }) {
    for (final permission in allPermissions) {
      if (permission.participantId == participantId &&
          permission.channelId == channelId) {
        return permission;
      }
    }
    return null;
  }
}
