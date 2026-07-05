import 'dart:typed_data';

import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_generator.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEventRadioRepository implements EventRadioRepository {
  SupabaseEventRadioRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<EventSession> joinByCode(String code) async {
    final normalized = InviteCodeParser.fromQrValue(code);
    if (normalized.isEmpty) {
      throw const JoinEventException('El codigo esta vacio.');
    }

    await _ensureAuthenticatedUser();
    final participantId = await _acceptInvite(normalized);

    final participantData = await _client
        .from('event_participants')
        .select('*, events(*)')
        .eq('id', participantId)
        .single();

    final eventData = participantData['events'] as Map<String, dynamic>?;
    if (eventData == null) {
      throw const JoinEventException(
        'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.',
      );
    }

    final event = EventRadioEvent.fromMap(eventData);
    final participant = EventParticipant.fromMap(participantData);
    return _loadSession(event: event, participant: participant);
  }

  @override
  Future<EventSession> refreshSession(EventSession session) async {
    final participantRow = await _client
        .from('event_participants')
        .select('*, events(*)')
        .eq('id', session.participant.id)
        .single();
    final eventData = participantRow['events'] as Map<String, dynamic>?;
    if (eventData == null) {
      throw const JoinEventException('La sesion ya no existe en el evento.');
    }
    final event = EventRadioEvent.fromMap(eventData);
    final participant = EventParticipant.fromMap(participantRow);
    return _loadSession(event: event, participant: participant);
  }

  Future<void> _ensureAuthenticatedUser() async {
    if (_client.auth.currentUser != null) return;

    try {
      await _client.auth.signInAnonymously();
    } on AuthException {
      throw const JoinEventException(
        'Inicia sesion para vincular esta invitacion.',
      );
    }
  }

  Future<String> _acceptInvite(String normalizedCode) async {
    try {
      final response = await _client.rpc(
        'accept_event_invite',
        params: {'invite_code_input': normalizedCode},
      );
      final errorMessage = _rpcString(response, 'error');
      if (errorMessage != null && errorMessage.isNotEmpty) {
        throw JoinEventException(errorMessage);
      }
      final participantId = _participantIdFromRpc(response);
      if (participantId == null || participantId.isEmpty) {
        throw const JoinEventException(
          'Codigo no encontrado. Revisalo o pedile uno nuevo al coordinador.',
        );
      }
      return participantId;
    } on JoinEventException {
      rethrow;
    } on PostgrestException catch (error) {
      throw JoinEventException(
        error.message.isEmpty
            ? 'No pudimos vincular esa invitacion.'
            : error.message,
      );
    }
  }

  String? _participantIdFromRpc(Object? response) {
    return _rpcString(response, 'participant_id');
  }

  String? _rpcString(Object? response, String key) {
    if (response is String && key == 'participant_id') return response;
    if (response is Map<String, dynamic>) {
      return response[key] as String?;
    }
    if (response is List && response.isNotEmpty) {
      return _rpcString(response.first, key);
    }
    return null;
  }

  @override
  Future<List<EventLog>> getEventLogs(String eventId) async {
    final rows = await _client
        .from('event_logs')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    return rows.map(EventLog.fromMap).toList();
  }

  @override
  Future<List<VoiceMessage>> getVoiceMessages(String channelId) async {
    final rows = await _client
        .from('voice_messages')
        .select('*, event_participants(display_name)')
        .eq('channel_id', channelId)
        .order('created_at', ascending: false);

    return rows.map(VoiceMessage.fromMap).toList();
  }

  @override
  Future<String?> getVoiceMessageAudioUrl(VoiceMessage message) async {
    if (message.audioUrl != null && message.audioUrl!.trim().isNotEmpty) {
      return message.audioUrl;
    }

    final storagePath = message.storagePath;
    if (storagePath == null || storagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage
        .from('event-audio')
        .createSignedUrl(storagePath, 60 * 30);
  }

  @override
  Future<int> transcribePendingMessages(
    String channelId, {
    List<String> messageIds = const [],
    int? limit,
  }) async {
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final response = await _client.functions.invoke(
      'transcribe-audio',
      body: {
        'channel_id': channelId,
        if (ids.isNotEmpty) 'message_ids': ids,
        if (limit != null) 'limit': limit,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final transcribedCount = data['transcribed_count'] as int? ?? 0;
      final failedCount = data['failed_count'] as int? ?? 0;
      if (transcribedCount == 0 && failedCount > 0) {
        throw StateError(
          data['error'] as String? ?? 'No pudimos transcribir los audios.',
        );
      }
      return transcribedCount;
    }
    if (data is Map) {
      final transcribedCount = data['transcribed_count'] as int? ?? 0;
      final failedCount = data['failed_count'] as int? ?? 0;
      if (transcribedCount == 0 && failedCount > 0) {
        throw StateError(
          data['error'] as String? ?? 'No pudimos transcribir los audios.',
        );
      }
      return transcribedCount;
    }
    return 0;
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
    final isBroadcast = channels.length > 1;
    final now = DateTime.now().toUtc();
    final rows = <Map<String, dynamic>>[];
    final browserTranscript = browserTranscriptionText?.trim();
    final hasBrowserTranscript =
        browserTranscript != null && browserTranscript.isNotEmpty;

    for (final (index, channel) in channels.indexed) {
      String? storagePath;
      if (audioBytes != null && audioBytes.isNotEmpty) {
        try {
          storagePath = await _uploadPttAudio(
            eventId: session.event.id,
            channelId: channel.id,
            participantId: session.participant.id,
            index: index,
            recordedAt: now,
            bytes: audioBytes,
            mimeType: audioMimeType,
          );
        } catch (_) {
          storagePath = null;
        }
      }

      rows.add({
        'event_id': session.event.id,
        'channel_id': channel.id,
        'participant_id': session.participant.id,
        'duration_seconds': durationSeconds,
        'storage_path': storagePath,
        'audio_url': null,
        'transcription_text': hasBrowserTranscript ? browserTranscript : null,
        'transcription_status': hasBrowserTranscript
            ? TranscriptionStatus.completed.value
            : TranscriptionStatus.pending.value,
        'transcription_provider':
            hasBrowserTranscript ? 'browser_speech' : null,
        'is_priority': channel.isEmergency || isBroadcast,
      });
    }

    final inserted = await _client
        .from('voice_messages')
        .insert(rows)
        .select('*, event_participants(display_name)')
        .order('created_at', ascending: false);

    await _client.from('event_logs').insert({
      'event_id': session.event.id,
      'participant_id': session.participant.id,
      'channel_id': isBroadcast ? null : channels.first.id,
      'type': isBroadcast
          ? 'broadcast_message'
          : channels.first.isEmergency
              ? 'emergency_message'
              : 'message_sent',
      'title': isBroadcast
          ? 'Broadcast enviado a ${channels.length} canales'
          : 'PTT enviado en ${channels.first.name}',
      'detail': isBroadcast
          ? 'Audio enviado a multiples canales.'
          : rows.any((row) => row['storage_path'] != null)
              ? 'Audio guardado en historial.'
              : audioBytes == null
                  ? 'Registro PTT guardado sin archivo de audio.'
                  : 'Registro PTT guardado; fallo la subida del audio.',
    });

    return inserted.map(VoiceMessage.fromMap).toList();
  }

  Future<String> _uploadPttAudio({
    required String eventId,
    required String channelId,
    required String participantId,
    required int index,
    required DateTime recordedAt,
    required Uint8List bytes,
    required String? mimeType,
  }) async {
    final contentType = mimeType ?? 'audio/webm';
    final extension = _audioExtensionFor(contentType);
    final storagePath = [
      eventId,
      channelId,
      '${recordedAt.microsecondsSinceEpoch}_${participantId}_$index.$extension',
    ].join('/');

    // Reintentos ante cortes de red: el audio del historial es valioso y
    // la subida ocurre justo despues de soltar el PTT.
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _client.storage.from('event-audio').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: false,
              ),
            );
        return storagePath;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    throw lastError!;
  }

  @override
  Future<VoiceMessage> sendSosAlert({
    required EventSession session,
    required EventChannel channel,
  }) async {
    _ensureCanSendSos(session: session, channel: channel);

    final inserted = await _client
        .from('voice_messages')
        .insert({
          'event_id': session.event.id,
          'channel_id': channel.id,
          'participant_id': session.participant.id,
          'duration_seconds': 0,
          'storage_path': null,
          'audio_url': null,
          'transcription_status': TranscriptionStatus.pending.value,
          'is_priority': true,
        })
        .select('*, event_participants(display_name)')
        .single();

    final message = VoiceMessage.fromMap(inserted);
    await _client.from('event_logs').insert({
      'event_id': session.event.id,
      'participant_id': session.participant.id,
      'channel_id': channel.id,
      'type': 'emergency_message',
      'title': 'SOS activado en ${channel.name}',
      'detail': 'Alerta prioritaria enviada.',
    });

    return message;
  }

  void _ensureCanSendSos({
    required EventSession session,
    required EventChannel channel,
  }) {
    if (!session.event.isOperational(DateTime.now())) {
      throw StateError('El evento no permite activar SOS.');
    }
    final permission = session.permissionFor(channel.id);
    if (permission == null || !permission.canListen || !permission.canTalk) {
      throw StateError('El permiso actual no permite activar SOS.');
    }
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
    final row = await _client
        .from('events')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'status': status.value,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', session.event.id)
        .select()
        .single();
    final event = EventRadioEvent.fromMap(row);
    await _insertLog(
      session: session,
      type: 'event_updated',
      title: 'Evento actualizado',
      detail: event.name,
    );
    return _loadSession(event: event, participant: session.participant);
  }

  @override
  Future<EventSession> createEvent({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await _ensureAuthenticatedUser();
    final response = await _client.rpc(
      'create_event_with_admin',
      params: {
        'event_name': name.trim(),
        'event_description': description.trim(),
        'starts_at_input': startsAt.toUtc().toIso8601String(),
        'ends_at_input': endsAt.toUtc().toIso8601String(),
        'admin_display_name': session.participant.displayName,
        'admin_phone': session.participant.phone,
        'admin_invite_code': InviteCodeGenerator().generate(),
      },
    );

    final participantId = _rpcString(response, 'participant_id');
    if (participantId == null || participantId.isEmpty) {
      throw StateError('No pudimos crear el evento en Supabase.');
    }

    final participantRow = await _client
        .from('event_participants')
        .select('*, events(*)')
        .eq('id', participantId)
        .single();
    final event = EventRadioEvent.fromMap(
      participantRow['events'] as Map<String, dynamic>,
    );
    final participant = EventParticipant.fromMap(participantRow);
    return _loadSession(event: event, participant: participant);
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
    final normalizedCode = _normalizeChannelCode(code);
    final row = await _client
        .from('event_channels')
        .insert({
          'event_id': session.event.id,
          'name': name.trim(),
          'code': normalizedCode,
          'description': description.trim(),
          'priority': priority.clamp(0, 100),
          'is_emergency': isEmergency,
          'livekit_room_name': 'event_${session.event.id}_$normalizedCode',
        })
        .select()
        .single();
    final channel = EventChannel.fromMap(row);

    final adminParticipants = session.participants.where(
      (participant) => participant.canAccessAdmin,
    );
    if (adminParticipants.isNotEmpty) {
      await _client.from('channel_members').insert(
            adminParticipants.map((participant) {
              return {
                'channel_id': channel.id,
                'participant_id': participant.id,
                'can_listen': true,
                'can_talk': true,
                'can_view_history': true,
              };
            }).toList(),
          );
    }
    await _insertLog(
      session: session,
      channelId: channel.id,
      type: 'channel_created',
      title: 'Canal creado: ${channel.name}',
      detail: channel.description,
    );
    return _loadSession(event: session.event, participant: session.participant);
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
    final row = await _client
        .from('event_channels')
        .update({
          'name': name.trim(),
          'code': _normalizeChannelCode(code),
          'description': description.trim(),
          'priority': priority.clamp(0, 100),
          'is_emergency': isEmergency,
        })
        .eq('id', channel.id)
        .select()
        .single();
    final updated = EventChannel.fromMap(row);
    await _insertLog(
      session: session,
      channelId: updated.id,
      type: 'channel_updated',
      title: 'Canal actualizado: ${updated.name}',
      detail: updated.description,
    );
    return _loadSession(event: session.event, participant: session.participant);
  }

  @override
  Future<EventSession> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  }) async {
    if (session.channels.length <= 1) return session;
    await _client.from('event_channels').delete().eq('id', channel.id);
    await _insertLog(
      session: session,
      channelId: channel.id,
      type: 'channel_deleted',
      title: 'Canal eliminado: ${channel.name}',
      detail: channel.code,
    );
    return _loadSession(event: session.event, participant: session.participant);
  }

  @override
  Future<EventSession> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    final row = await _client
        .from('event_participants')
        .insert({
          'event_id': session.event.id,
          'display_name': displayName.trim(),
          'phone': phone.trim(),
          'role': role.value,
          'invite_code': _normalizeInviteCode(inviteCode),
          'invite_status': 'pending',
          // El codigo vale hasta que termina el evento (no vence por tiempo).
          'invite_expires_at': session.event.endsAt.toUtc().toIso8601String(),
        })
        .select()
        .single();
    final participant = EventParticipant.fromMap(row);
    if (session.channels.isNotEmpty) {
      await _client.from('channel_members').insert(
            session.channels.map((channel) {
              return {
                'channel_id': channel.id,
                'participant_id': participant.id,
                'can_listen': true,
                'can_talk': role != ParticipantRole.viewer,
                'can_view_history': true,
              };
            }).toList(),
          );
    }
    await _insertLog(
      session: session,
      type: 'participant_invited',
      title: 'Participante invitado: ${participant.displayName}',
      detail: participant.role.value,
    );
    return _loadSession(event: session.event, participant: session.participant);
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
    final normalizedInviteCode = _normalizeInviteCode(inviteCode);
    final inviteChanged = normalizedInviteCode != participant.inviteCode;
    final row = await _client
        .from('event_participants')
        .update({
          'display_name': displayName.trim(),
          'phone': phone.trim(),
          'role': role.value,
          'invite_code': normalizedInviteCode,
          if (inviteChanged) 'auth_user_id': null,
          if (inviteChanged) 'invite_status': 'pending',
          if (inviteChanged) 'joined_at': null,
          if (inviteChanged) 'accepted_at': null,
          if (inviteChanged) 'invite_revoked_at': null,
          if (inviteChanged)
            'invite_expires_at': session.event.endsAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', participant.id)
        .select()
        .single();
    final updated = EventParticipant.fromMap(row);
    if (updated.role == ParticipantRole.viewer) {
      await _client
          .from('channel_members')
          .update({'can_talk': false}).eq('participant_id', updated.id);
    }
    await _insertLog(
      session: session,
      type: 'participant_updated',
      title: 'Participante actualizado: ${updated.displayName}',
      detail: updated.role.value,
    );
    final currentParticipant =
        updated.id == session.participant.id ? updated : session.participant;
    return _loadSession(event: session.event, participant: currentParticipant);
  }

  @override
  Future<EventSession> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  }) async {
    if (participant.id == session.participant.id) return session;
    await _client.from('event_participants').delete().eq('id', participant.id);
    await _insertLog(
      session: session,
      type: 'participant_deleted',
      title: 'Participante eliminado: ${participant.displayName}',
      detail: participant.role.value,
    );
    return _loadSession(event: session.event, participant: session.participant);
  }

  @override
  Future<EventSession> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  }) async {
    await _client
        .from('channel_members')
        .delete()
        .eq('participant_id', participant.id);
    final participantRole = session.participants
        .where((item) => item.id == participant.id)
        .firstOrNull
        ?.role;
    final rows = permissions.where((permission) => permission.canListen).map(
      (permission) {
        return {
          'channel_id': permission.channelId,
          'participant_id': participant.id,
          'can_listen': true,
          'can_talk': permission.canTalk &&
              (participantRole ?? participant.role) != ParticipantRole.viewer,
          'can_view_history': permission.canViewHistory,
        };
      },
    ).toList();
    if (rows.isNotEmpty) {
      await _client.from('channel_members').insert(rows);
    }
    await _insertLog(
      session: session,
      type: 'participant_channels_updated',
      title: 'Canales actualizados: ${participant.displayName}',
      detail: '${rows.length} canales',
    );
    return _loadSession(event: session.event, participant: session.participant);
  }

  Future<EventSession> _loadSession({
    required EventRadioEvent event,
    required EventParticipant participant,
  }) async {
    final memberRows = await _client
        .from('channel_members')
        .select('*, event_channels(*)')
        .eq('participant_id', participant.id);
    final channels = <EventChannel>[];
    final permissions = <ChannelPermission>[];
    for (final member in memberRows) {
      final permission = _permissionFromMap(member);
      permissions.add(permission);
      if (permission.canListen) {
        channels.add(
          EventChannel.fromMap(
            member['event_channels'] as Map<String, dynamic>,
          ),
        );
      }
    }

    final participants = <EventParticipant>[];
    final allPermissions = <ChannelPermission>[];
    if (participant.canAccessAdmin) {
      final participantRows = await _client
          .from('event_participants')
          .select()
          .eq('event_id', event.id)
          .order('display_name');
      participants.addAll(participantRows.map(EventParticipant.fromMap));

      final allMemberRows = await _client
          .from('channel_members')
          .select('*, event_channels!inner(event_id)')
          .eq('event_channels.event_id', event.id);
      allPermissions.addAll(allMemberRows.map(_permissionFromMap));
    }

    return EventSession(
      event: event,
      participant: participant,
      channels: channels,
      permissions: permissions,
      participants: participants,
      allPermissions: allPermissions,
    );
  }

  ChannelPermission _permissionFromMap(Map<String, dynamic> map) {
    return ChannelPermission(
      channelId: map['channel_id'] as String,
      participantId: map['participant_id'] as String,
      canListen: map['can_listen'] as bool? ?? true,
      canTalk: map['can_talk'] as bool? ?? true,
      canViewHistory: map['can_view_history'] as bool? ?? true,
    );
  }

  Future<void> _insertLog({
    EventSession? session,
    String? eventId,
    String? participantId,
    String? channelId,
    required String type,
    required String title,
    String? detail,
  }) async {
    await _client.from('event_logs').insert({
      'event_id': eventId ?? session!.event.id,
      'participant_id': participantId ?? session?.participant.id,
      'channel_id': channelId,
      'type': type,
      'title': title,
      'detail': detail,
    });
  }

  String _normalizeChannelCode(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _normalizeInviteCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }
}

String _audioExtensionFor(String mimeType) {
  final normalized = mimeType.toLowerCase();
  if (normalized.contains('webm')) return 'webm';
  if (normalized.contains('ogg') || normalized.contains('opus')) return 'opus';
  if (normalized.contains('mp4') || normalized.contains('aac')) return 'm4a';
  if (normalized.contains('wav')) return 'wav';
  if (normalized.contains('mpeg') || normalized.contains('mp3')) return 'mp3';
  return 'audio';
}
