import 'dart:typed_data';

import 'package:event_radio_app/src/shared/domain/event_models.dart';

abstract class EventRadioRepository {
  Future<EventSession> joinByCode(String code);

  /// Recarga la sesion actual desde la fuente de datos. Lo usa la
  /// sincronizacion realtime cuando el backend notifica cambios.
  Future<EventSession> refreshSession(EventSession session);

  Future<List<VoiceMessage>> getVoiceMessages(String channelId);

  Future<String?> getVoiceMessageAudioUrl(VoiceMessage message);

  Future<int> transcribePendingMessages(
    String channelId, {
    List<String> messageIds = const [],
    int? limit,
  });

  Future<List<EventLog>> getEventLogs(String eventId);

  Future<List<VoiceMessage>> sendPttMessage({
    required EventSession session,
    required List<EventChannel> channels,
    required int durationSeconds,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? browserTranscriptionText,
  });

  Future<VoiceMessage> sendSosAlert({
    required EventSession session,
    required EventChannel channel,
  });

  Future<EventSession> updateEventDetails({
    required EventSession session,
    required String name,
    required String description,
    required EventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<EventSession> createEvent({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<EventSession> createChannel({
    required EventSession session,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  });

  Future<EventSession> updateChannel({
    required EventSession session,
    required EventChannel channel,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  });

  Future<EventSession> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  });

  Future<EventSession> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  });

  Future<EventSession> updateParticipant({
    required EventSession session,
    required EventParticipant participant,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  });

  Future<EventSession> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  });

  Future<EventSession> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  });
}

class JoinEventException implements Exception {
  const JoinEventException(this.message);

  final String message;

  @override
  String toString() => message;
}
