import 'dart:typed_data';

import 'package:event_radio_app/src/shared/domain/event_models.dart';

/// Contrato de acceso a datos para la aplicacion de radio operativa.
///
/// Define las operaciones CRUD sobre eventos, canales, participantes y
/// mensajes de voz. Las implementaciones concretas son
/// [SupabaseEventRadioRepository] (produccion) y
/// [MockEventRadioRepository] (modo demo / tests).
abstract class EventRadioRepository {
  /// Ingresa a un evento usando un codigo de invitacion.
  ///
  /// Lanza [JoinEventException] si el codigo no existe o ya fue usado.
  Future<EventSession> joinByCode(String code);

  /// Recarga la sesion actual desde la fuente de datos. Lo usa la
  /// sincronizacion realtime cuando el backend notifica cambios.
  Future<EventSession> refreshSession(EventSession session);

  /// Obtiene los mensajes de voz de un canal, ordenados por fecha.
  Future<List<VoiceMessage>> getVoiceMessages(String channelId);

  /// Devuelve la URL firmada para reproducir el audio de un mensaje.
  ///
  /// Retorna `null` si el mensaje no tiene audio almacenado.
  Future<String?> getVoiceMessageAudioUrl(VoiceMessage message);

  /// Solicita la transcripcion de mensajes pendientes en un canal.
  ///
  /// Retorna la cantidad de mensajes enviados a transcribir.
  Future<int> transcribePendingMessages(
    String channelId, {
    List<String> messageIds = const [],
    int? limit,
  });

  /// Obtiene el historial de logs del evento (ingresos, alertas, etc.).
  Future<List<EventLog>> getEventLogs(String eventId);

  /// Guarda un mensaje PTT: audio, transcripcion y metadatos.
  ///
  /// [channels] permite broadcast: el mensaje se registra en cada canal.
  /// Retorna la lista de mensajes creados (uno por canal).
  Future<List<VoiceMessage>> sendPttMessage({
    required EventSession session,
    required List<EventChannel> channels,
    required int durationSeconds,
    Uint8List? audioBytes,
    String? audioMimeType,
    String? browserTranscriptionText,
  });

  /// Envia una alerta SOS al canal indicado.
  Future<VoiceMessage> sendSosAlert({
    required EventSession session,
    required EventChannel channel,
  });

  /// Actualiza nombre, descripcion, estado y horarios del evento.
  Future<EventSession> updateEventDetails({
    required EventSession session,
    required String name,
    required String description,
    required EventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  /// Crea un nuevo evento asociado a la sesion actual.
  Future<EventSession> createEvent({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  /// Agrega un canal al evento con su configuracion inicial.
  Future<EventSession> createChannel({
    required EventSession session,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  });

  /// Modifica la configuracion de un canal existente.
  Future<EventSession> updateChannel({
    required EventSession session,
    required EventChannel channel,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  });

  /// Elimina un canal del evento.
  Future<EventSession> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  });

  /// Agrega un participante al evento con codigo de invitacion.
  Future<EventSession> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  });

  /// Actualiza los datos de un participante existente.
  Future<EventSession> updateParticipant({
    required EventSession session,
    required EventParticipant participant,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  });

  /// Elimina un participante del evento.
  Future<EventSession> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  });

  /// Actualiza los permisos de canal de un participante.
  Future<EventSession> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  });
}

/// Codigos tipados para errores de ingreso a eventos.
///
/// Permiten que la capa de presentacion mapee cada caso a una cadena i18n
/// sin acoplar el repositorio al idioma de la UI.
enum JoinErrorCode {
  /// El codigo de invitacion esta vacio.
  emptyCode,

  /// El codigo no corresponde a ningun evento activo.
  codeNotFound,

  /// La sesion ya no existe en el backend.
  sessionExpired,

  /// Se requiere autenticacion para vincular la invitacion.
  authRequired,

  /// La vinculacion con el backend fallo (error generico de RPC/DB).
  inviteFailed,

  /// Error inesperado o mensaje provisto por el servidor.
  unknown,
}

/// Excepcion lanzada cuando el ingreso a un evento falla.
///
/// Causas comunes: codigo invalido, expirado, o participante ya registrado.
class JoinEventException implements Exception {
  /// Crea una excepcion de ingreso con un [code] tipado.
  ///
  /// [serverMessage] es opcional y contiene el mensaje original del servidor,
  /// util para diagnostico o como fallback cuando no hay cadena i18n.
  const JoinEventException(this.code, {this.serverMessage});

  /// Codigo tipado del error.
  final JoinErrorCode code;

  /// Mensaje original del servidor (diagnostico/fallback).
  final String? serverMessage;

  /// Descripcion legible del error — preferir [code] para mapeo i18n.
  String get message => serverMessage ?? code.name;

  @override
  String toString() => message;
}
