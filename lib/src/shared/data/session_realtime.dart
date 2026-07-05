import 'dart:async';

import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alerta SOS recibida en vivo desde otro dispositivo del evento.
class SosAlert {
  const SosAlert({
    required this.messageId,
    required this.channelId,
    required this.createdAt,
  });

  final String messageId;
  final String channelId;
  final DateTime createdAt;
}

/// Mantiene la sesion sincronizada en tiempo real con Supabase: cambios de
/// evento, canales, participantes y permisos hechos por el admin llegan solos
/// a todos los dispositivos, sin recargar. Tambien refresca el historial ante
/// mensajes nuevos y emite alertas SOS entrantes.
///
/// Se activa haciendo `ref.watch(sessionRealtimeProvider)` desde las pantallas
/// del evento. En modo mock no hace nada.
final sessionRealtimeProvider = Provider<SessionRealtimeSync>((ref) {
  final sync = SessionRealtimeSync(ref);
  ref.onDispose(sync.dispose);
  sync.start();
  return sync;
});

final sosAlertsProvider = StreamProvider<SosAlert>((ref) {
  return ref.watch(sessionRealtimeProvider).sosAlerts;
});

class SessionRealtimeSync {
  SessionRealtimeSync(this._ref);

  final Ref _ref;
  RealtimeChannel? _channel;
  String? _subscribedEventId;
  Timer? _refreshDebounce;
  final StreamController<SosAlert> _sosController =
      StreamController<SosAlert>.broadcast();

  Stream<SosAlert> get sosAlerts => _sosController.stream;

  void start() {
    if (!EnvConfig.isSupabaseAvailable) return;

    _ref.listen<AsyncValue<EventSession?>>(
      currentSessionProvider,
      (previous, next) {
        final eventId = next.valueOrNull?.event.id;
        if (eventId != _subscribedEventId) {
          _resubscribe(eventId);
        }
      },
      fireImmediately: true,
    );
  }

  void dispose() {
    _refreshDebounce?.cancel();
    _teardownChannel();
    _sosController.close();
  }

  void _teardownChannel() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  void _resubscribe(String? eventId) {
    _teardownChannel();
    _subscribedEventId = eventId;
    if (eventId == null) return;

    final client = Supabase.instance.client;
    final channel = client.channel('event-sync-$eventId');

    // Cambios de estructura del evento (admin): refrescan la sesion con
    // debounce para agrupar rachas de cambios.
    for (final table in const [
      'events',
      'event_channels',
      'event_participants',
      'channel_members',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _scheduleSessionRefresh(),
      );
    }

    // Mensajes nuevos: refrescan historial del canal y bitacora, y emiten
    // alerta si es prioritario (SOS / emergencia).
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'voice_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: eventId,
      ),
      callback: _handleVoiceMessageInsert,
    );

    channel.subscribe();
    _channel = channel;
  }

  void _scheduleSessionRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_ref.read(currentSessionProvider.notifier).refresh());
    });
  }

  void _handleVoiceMessageInsert(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final channelId = record['channel_id'] as String?;
    final messageId = record['id'] as String?;
    if (channelId == null || messageId == null) return;

    _ref.invalidate(voiceMessagesProvider(channelId));
    final eventId = record['event_id'] as String?;
    if (eventId != null) {
      _ref.invalidate(eventLogsProvider(eventId));
    }

    final session = _ref.read(currentSessionProvider).valueOrNull;
    final isOwnMessage =
        record['participant_id'] == session?.participant.id;
    final isPriority = record['is_priority'] == true;
    if (isPriority && !isOwnMessage && !_sosController.isClosed) {
      _sosController.add(
        SosAlert(
          messageId: messageId,
          channelId: channelId,
          createdAt: DateTime.tryParse(
                record['created_at'] as String? ?? '',
              )?.toLocal() ??
              DateTime.now(),
        ),
      );
    }
  }
}
