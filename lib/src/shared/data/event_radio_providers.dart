import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/shared/data/mock_event_radio_repository.dart';
import 'package:event_radio_app/src/shared/data/supabase_event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/event_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventRadioRepositoryProvider = Provider<EventRadioRepository>((ref) {
  if (EnvConfig.isSupabaseAvailable) {
    return SupabaseEventRadioRepository();
  }
  return MockEventRadioRepository();
});

final currentSessionProvider =
    StateNotifierProvider<CurrentSessionController, AsyncValue<EventSession?>>(
        (ref) {
  return CurrentSessionController(ref.watch(eventRadioRepositoryProvider));
});

/// Controlador de la sesion activa del usuario.
///
/// Envuelve las operaciones del [EventRadioRepository] con manejo de estado
/// [AsyncValue]: loading mientras opera, data con el resultado, y restauracion
/// del estado anterior si una mutacion falla (patron state-preservation).
///
/// Cada metodo de mutacion guarda `state` antes de operar y lo restaura
/// en el `catch`, de modo que un error de red nunca deja la UI sin sesion.
class CurrentSessionController
    extends StateNotifier<AsyncValue<EventSession?>> {
  /// Crea el controlador con el repositorio inyectado.
  CurrentSessionController(this._repository)
      : super(const AsyncValue.data(null));

  final EventRadioRepository _repository;

  /// Ingresa a un evento usando un codigo de invitacion.
  ///
  /// Pone el estado en loading, luego en data con la sesion resultante.
  /// Si falla, pone el error en el estado y relanza la excepcion.
  Future<EventSession> joinByCode(String code) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.joinByCode(code);
      state = AsyncValue.data(session);
      return session;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  /// Recarga silenciosa de la sesion (disparada por realtime). Si falla,
  /// se conserva el estado actual para no interrumpir la operacion.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      state = AsyncValue.data(await _repository.refreshSession(current));
    } catch (_) {
      // La proxima notificacion realtime o accion manual vuelve a intentar.
    }
  }

  Future<void> updateEventDetails({
    required EventSession session,
    required String name,
    required String description,
    required EventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.updateEventDetails(
          session: session,
          name: name,
          description: description,
          status: status,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> createEvent({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.createEvent(
          session: session,
          name: name,
          description: description,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> createChannel({
    required EventSession session,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.createChannel(
          session: session,
          name: name,
          code: code,
          description: description,
          priority: priority,
          isEmergency: isEmergency,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Crea un evento y le aplica los canales de una plantilla. El evento nuevo
  /// ya trae el canal "Produccion"; aca se suman los canales adicionales.
  /// Devuelve la lista de codigos de canal que no se pudieron crear.
  Future<List<String>> createEventFromTemplate({
    required EventSession session,
    required String name,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    required EventTemplate template,
  }) async {
    await createEvent(
      session: session,
      name: name,
      description: description,
      startsAt: startsAt,
      endsAt: endsAt,
    );

    final failedCodes = <String>[];
    for (final channel in template.additionalChannels) {
      final current = state.valueOrNull;
      if (current == null) break;
      try {
        await createChannel(
          session: current,
          name: channel.name,
          code: channel.code,
          description: channel.description,
          priority: channel.priority,
          isEmergency: channel.isEmergency,
        );
      } catch (_) {
        failedCodes.add(channel.code);
      }
    }
    return failedCodes;
  }

  Future<void> updateChannel({
    required EventSession session,
    required EventChannel channel,
    required String name,
    required String code,
    required String description,
    required int priority,
    required bool isEmergency,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.updateChannel(
          session: session,
          channel: channel,
          name: name,
          code: code,
          description: description,
          priority: priority,
          isEmergency: isEmergency,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> deleteChannel({
    required EventSession session,
    required EventChannel channel,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.deleteChannel(
          session: session,
          channel: channel,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> createParticipant({
    required EventSession session,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.createParticipant(
          session: session,
          displayName: displayName,
          phone: phone,
          role: role,
          inviteCode: inviteCode,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> updateParticipant({
    required EventSession session,
    required EventParticipant participant,
    required String displayName,
    required String phone,
    required ParticipantRole role,
    required String inviteCode,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.updateParticipant(
          session: session,
          participant: participant,
          displayName: displayName,
          phone: phone,
          role: role,
          inviteCode: inviteCode,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> deleteParticipant({
    required EventSession session,
    required EventParticipant participant,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.deleteParticipant(
          session: session,
          participant: participant,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> updateParticipantChannels({
    required EventSession session,
    required EventParticipant participant,
    required List<ChannelPermission> permissions,
  }) async {
    final previous = state;
    try {
      state = AsyncValue.data(
        await _repository.updateParticipantChannels(
          session: session,
          participant: participant,
          permissions: permissions,
        ),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final voiceMessagesProvider =
    FutureProvider.family<List<VoiceMessage>, String>((ref, channelId) {
  return ref.watch(eventRadioRepositoryProvider).getVoiceMessages(channelId);
});

final eventLogsProvider =
    FutureProvider.family<List<EventLog>, String>((ref, eventId) {
  return ref.watch(eventRadioRepositoryProvider).getEventLogs(eventId);
});
