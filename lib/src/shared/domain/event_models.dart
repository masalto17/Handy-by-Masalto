/// Ciclo de vida de un evento operativo.
///
/// Un evento se crea como [draft], pasa a [scheduled] cuando tiene fecha,
/// se activa con [active] durante la operacion, y termina como [closed]
/// o [cancelled].
enum EventStatus {
  /// Borrador: el evento esta siendo configurado.
  draft('draft'),

  /// Programado: tiene fecha de inicio y fin asignadas.
  scheduled('scheduled'),

  /// Activo: la operacion esta en curso, los canales PTT estan habilitados.
  active('active'),

  /// Cerrado: la operacion finalizo normalmente.
  closed('closed'),

  /// Cancelado: la operacion fue cancelada antes de finalizar.
  cancelled('cancelled');

  const EventStatus(this.value);

  /// Valor almacenado en la base de datos.
  final String value;

  /// Convierte un string de la DB al enum correspondiente.
  ///
  /// Retorna [draft] si el valor no coincide con ningun estado.
  static EventStatus fromValue(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => EventStatus.draft,
    );
  }
}

/// Roles que un participante puede tener dentro de un evento.
///
/// Los permisos se derivan del rol: [admin] y [coordinator] acceden al
/// panel de administracion; [participant] opera la radio; [viewer] solo
/// escucha.
enum ParticipantRole {
  /// Administrador: control total del evento.
  admin('admin'),

  /// Coordinador: administra canales y participantes.
  coordinator('coordinator'),

  /// Participante: puede hablar y escuchar en canales asignados.
  participant('participant'),

  /// Observador: solo escucha, sin acceso al microfono.
  viewer('viewer');

  const ParticipantRole(this.value);

  /// Valor almacenado en la base de datos.
  final String value;

  /// Convierte un string de la DB al enum correspondiente.
  ///
  /// Retorna [participant] si el valor no coincide con ningun rol.
  static ParticipantRole fromValue(String value) {
    return ParticipantRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ParticipantRole.participant,
    );
  }
}

/// Estado de la transcripcion de un mensaje de voz.
enum TranscriptionStatus {
  /// Pendiente de envio a transcribir.
  pending('pending'),

  /// En cola del servicio de transcripcion.
  queued('queued'),

  /// El servicio esta procesando el audio.
  processing('processing'),

  /// Transcripcion completada exitosamente.
  completed('completed'),

  /// La transcripcion fallo (audio corrupto, servicio caido, etc.).
  failed('failed'),

  /// Se omitio la transcripcion (mensaje sin audio, SOS, etc.).
  skipped('skipped');

  const TranscriptionStatus(this.value);

  /// Valor almacenado en la base de datos.
  final String value;

  /// Convierte un string de la DB al enum correspondiente.
  ///
  /// Retorna [pending] si el valor no coincide con ningun estado.
  static TranscriptionStatus fromValue(String value) {
    return TranscriptionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TranscriptionStatus.pending,
    );
  }
}

/// Evento operativo — la unidad raiz que agrupa canales y participantes.
///
/// Representa una operacion acotada en el tiempo (festival, operativo de
/// seguridad, evento deportivo) con un ciclo de vida [EventStatus].
class EventRadioEvent {
  /// Crea un evento con sus datos basicos.
  const EventRadioEvent({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.description,
    this.createdBy,
  });

  /// Identificador unico (UUID).
  final String id;

  /// Nombre visible del evento.
  final String name;

  /// Descripcion opcional del evento.
  final String? description;

  /// Inicio programado de la operacion (hora local).
  final DateTime startsAt;

  /// Fin programado de la operacion (hora local).
  final DateTime endsAt;

  /// Estado actual del ciclo de vida.
  final EventStatus status;

  /// ID del usuario que creo el evento (puede ser `null` en seeds).
  final String? createdBy;

  /// Retorna `true` si el evento esta activo y dentro de su ventana horaria.
  bool isOperational(DateTime now) {
    return status == EventStatus.active &&
        !now.isBefore(startsAt) &&
        now.isBefore(endsAt);
  }

  /// `true` si el evento ya no acepta operacion (cerrado o cancelado).
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

/// Canal de radio dentro de un evento.
///
/// Cada canal tiene su propia sala LiveKit. Los canales con [isEmergency]
/// activan el ducking automatico: al hablar en un canal de emergencia se
/// silencian los demas.
class EventChannel {
  /// Crea un canal con su configuracion.
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

  /// Identificador unico (UUID).
  final String id;

  /// Evento al que pertenece este canal.
  final String eventId;

  /// Nombre visible del canal (e.g. "Seguridad", "Logistica").
  final String name;

  /// Codigo corto para identificar el canal en la UI.
  final String code;

  /// Descripcion opcional del canal.
  final String? description;

  /// Prioridad para ordenar canales: mayor numero = mas arriba.
  final int priority;

  /// Si es `true`, activa ducking automatico al hablar.
  final bool isEmergency;

  /// Nombre de la sala LiveKit asociada a este canal.
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

/// Participante registrado en un evento con su rol y estado de invitacion.
class EventParticipant {
  /// Crea un participante con sus datos de registro.
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

  /// Identificador unico (UUID).
  final String id;

  /// Evento al que pertenece.
  final String eventId;

  /// ID de Supabase Auth (vinculado al iniciar sesion).
  final String? authUserId;

  /// Nombre visible en la radio.
  final String displayName;

  /// Telefono de contacto (opcional).
  final String? phone;

  /// Rol que determina los permisos del participante.
  final ParticipantRole role;

  /// Codigo unico de invitacion para ingresar al evento.
  final String inviteCode;

  /// Estado de la invitacion: `pending`, `accepted`, etc.
  final String inviteStatus;

  /// Momento en que el participante ingreso al evento.
  final DateTime? joinedAt;

  /// `true` si el participante puede acceder al panel de administracion.
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

/// Permisos de un participante sobre un canal especifico.
///
/// Controla si puede escuchar, hablar o ver el historial de mensajes.
class ChannelPermission {
  /// Crea un permiso con los accesos indicados (todos habilitados por defecto).
  const ChannelPermission({
    required this.channelId,
    required this.participantId,
    this.canListen = true,
    this.canTalk = true,
    this.canViewHistory = true,
  });

  /// Canal al que aplica este permiso.
  final String channelId;

  /// Participante al que aplica este permiso.
  final String participantId;

  /// Puede escuchar audio del canal.
  final bool canListen;

  /// Puede transmitir (PTT) en el canal.
  final bool canTalk;

  /// Puede ver el historial de mensajes del canal.
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

/// Mensaje de voz transmitido por PTT en un canal.
///
/// Contiene la referencia al audio (URL o storage path), la transcripcion
/// y metadatos como duracion y prioridad (SOS).
class VoiceMessage {
  /// Crea un mensaje de voz con sus datos.
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

  /// Identificador unico (UUID).
  final String id;

  /// Evento al que pertenece este mensaje.
  final String eventId;

  /// Canal donde se transmitio.
  final String channelId;

  /// Participante que envio el mensaje.
  final String participantId;

  /// Nombre visible del emisor.
  final String senderName;

  /// URL publica del audio (para reproduccion directa).
  final String? audioUrl;

  /// Ruta en Supabase Storage (para generar URL firmada).
  final String? storagePath;

  /// Duracion del audio en segundos.
  final double? durationSeconds;

  /// Texto de la transcripcion (puede venir de browser o backend).
  final String? transcriptionText;

  /// Estado actual de la transcripcion.
  final TranscriptionStatus transcriptionStatus;

  /// Servicio que realizo la transcripcion (e.g. "openai").
  final String? transcriptionProvider;

  /// ID del job de transcripcion en el servicio externo.
  final String? transcriptionJobId;

  /// `true` para alertas SOS y mensajes de emergencia.
  final bool isPriority;

  /// Momento de envio del mensaje (hora local).
  final DateTime createdAt;

  /// Alias de [transcriptionText] para compatibilidad.
  String? get transcription => transcriptionText;

  /// `true` si el mensaje tiene audio almacenado.
  bool get hasAudio => audioUrl != null || storagePath != null;

  /// `true` si la transcripcion ya alcanzo un estado terminal.
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

/// Entrada del log de actividad del evento.
///
/// Registra acciones como ingresos, alertas SOS, cambios de estado, etc.
class EventLog {
  /// Crea una entrada de log.
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

  /// Identificador unico (UUID).
  final String id;

  /// Evento al que pertenece esta entrada.
  final String eventId;

  /// Participante que origino la accion (si aplica).
  final String? participantId;

  /// Canal relacionado (si aplica).
  final String? channelId;

  /// Tipo de evento (e.g. "join", "sos", "status_change").
  final String type;

  /// Titulo legible de la accion.
  final String title;

  /// Detalle adicional (opcional).
  final String? detail;

  /// Momento de la accion (hora local).
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

/// Sesion activa de un participante en un evento.
///
/// Agrupa toda la informacion necesaria para operar la radio: el evento,
/// el participante autenticado, los canales disponibles y los permisos.
/// Es el objeto raiz que se pasa a la mayoria de las operaciones del
/// repositorio.
class EventSession {
  /// Crea una sesion con el contexto completo del participante.
  const EventSession({
    required this.event,
    required this.participant,
    required this.channels,
    required this.permissions,
    this.participants = const [],
    this.allPermissions = const [],
  });

  /// Evento al que pertenece esta sesion.
  final EventRadioEvent event;

  /// Participante autenticado en esta sesion.
  final EventParticipant participant;

  /// Canales disponibles para este participante.
  final List<EventChannel> channels;

  /// Permisos de este participante sobre los canales.
  final List<ChannelPermission> permissions;

  /// Todos los participantes del evento (solo visible para admin).
  final List<EventParticipant> participants;

  /// Todos los permisos del evento (solo visible para admin).
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

  /// Canales ordenados por prioridad descendente (emergencia primero).
  List<EventChannel> get orderedChannels {
    final ordered = [...channels];
    ordered.sort((a, b) => b.priority.compareTo(a.priority));
    return ordered;
  }

  /// Busca un canal por su [id]. Retorna `null` si no existe.
  EventChannel? channelById(String id) {
    for (final channel in channels) {
      if (channel.id == id) return channel;
    }
    return null;
  }

  /// Permisos del participante actual sobre el canal [channelId].
  ChannelPermission? permissionFor(String channelId) {
    for (final permission in permissions) {
      if (permission.channelId == channelId) return permission;
    }
    return null;
  }

  /// Permisos de un participante especifico sobre un canal (vista admin).
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
