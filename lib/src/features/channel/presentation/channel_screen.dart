import 'dart:async';

import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/channel/presentation/push_to_talk_button.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/data/session_realtime.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:event_radio_app/src/shared/presentation/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({required this.channelId, super.key});

  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  bool _broadcastAll = false;
  bool _isSendingSos = false;
  bool _isPreparingAudio = false;
  bool _audioReady = false;
  String? _audioError;
  String? _preparedChannelId;
  late final AudioRoomService _audioService;

  @override
  void initState() {
    super.initState();
    // Se captura aca porque "ref" no puede usarse dentro de dispose().
    _audioService = ref.read(audioRoomServiceProvider);
    // Dentro de un canal la pantalla no debe bloquearse: el operador tiene
    // que poder escuchar y responder al instante durante todo el evento.
    // El catchError cubre plataformas sin soporte (y los widget tests).
    unawaited(WakelockPlus.enable().catchError((_) {}));
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((_) {}));
    // Al salir del canal se cortan las salas LiveKit para no consumir
    // minutos de audio sin nadie escuchando.
    unawaited(_audioService.stopListening());
    super.dispose();
  }

  Future<void> _prepareListening({
    required EventSession session,
    required EventChannel channel,
    required bool canListen,
    required bool canOperate,
  }) async {
    if (!canOperate || !canListen || _preparedChannelId == channel.id) return;

    _preparedChannelId = channel.id;
    setState(() {
      _isPreparingAudio = true;
      _audioReady = false;
      _audioError = null;
    });

    try {
      await ref
          .read(audioRoomServiceProvider)
          .prepareListening(session: session, channels: [channel]);
      if (!mounted) return;
      setState(() {
        _isPreparingAudio = false;
        _audioReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPreparingAudio = false;
        _audioReady = false;
        _audioError = 'No pudimos conectar escucha LiveKit.';
      });
    }
  }

  Future<void> _sendSos({
    required EventSession session,
    required EventChannel channel,
  }) async {
    if (_isSendingSos) return;

    setState(() => _isSendingSos = true);
    try {
      await ref
          .read(eventRadioRepositoryProvider)
          .sendSosAlert(session: session, channel: channel);
      ref.invalidate(voiceMessagesProvider(channel.id));
      ref.invalidate(eventLogsProvider(session.event.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS activado en ${channel.name}.')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No pudimos activar SOS.')));
    } finally {
      if (mounted) {
        setState(() => _isSendingSos = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mantiene viva la sincronizacion realtime tambien dentro del canal.
    ref.watch(sessionRealtimeProvider);

    return AppScaffold(
      title: 'CANAL',
      actions: const [LeaveEventAction()],
      child: SessionGuard(
        builder: (context, session) {
          final channel = session.channelById(widget.channelId);
          if (channel == null) {
            return const Center(child: Text('Canal no asignado.'));
          }

          final permission = session.permissionFor(channel.id);
          final canOperate = session.event.isOperational(DateTime.now());
          final canListen = permission?.canListen ?? false;
          final canBroadcast =
              session.participant.canAccessAdmin && session.channels.length > 1;
          final targetChannels =
              _broadcastAll && canBroadcast ? session.channels : [channel];
          final destinationLabel = _broadcastAll && canBroadcast
              ? 'todos los canales'
              : channel.name;
          final canTalk = canOperate &&
              (_broadcastAll && canBroadcast
                  ? true
                  : permission?.canTalk ?? false);
          final canSendSos =
              canOperate && canListen && (permission?.canTalk ?? false);
          final compactLayout = MediaQuery.sizeOf(context).height < 720;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              _prepareListening(
                session: session,
                channel: channel,
                canListen: canListen,
                canOperate: canOperate,
              ),
            );
          });

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ChannelHeader(channel: channel),
                      if (canBroadcast) ...[
                        const SizedBox(height: 18),
                        _BroadcastTargetSelector(
                          broadcastAll: _broadcastAll,
                          totalChannels: session.channels.length,
                          onChanged: (value) {
                            setState(() => _broadcastAll = value);
                          },
                        ),
                      ],
                      if (!compactLayout) ...[
                        const SizedBox(height: 16),
                        _AudioConnectionStatus(
                          isPreparing: _isPreparingAudio,
                          isReady: _audioReady,
                          error: _audioError,
                          canListen: canListen,
                          canOperate: canOperate,
                        ),
                      ],
                      _ChannelPresenceBar(channelId: channel.id),
                      SizedBox(height: compactLayout ? 12 : 28),
                      PushToTalkButton(
                        session: session,
                        channels: targetChannels,
                        destinationLabel: destinationLabel,
                        canTalk: canTalk,
                      ),
                      SizedBox(height: compactLayout ? 12 : 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/history/${channel.id}'),
                              icon: const Icon(Icons.history),
                              label: const Text('Historial'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: canSendSos && !_isSendingSos
                                  ? () => _sendSos(
                                        session: session,
                                        channel: channel,
                                      )
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: AppTheme.danger.withValues(
                                  alpha: 0.92,
                                ),
                                side: const BorderSide(color: AppTheme.danger),
                              ),
                              icon: _isSendingSos
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.warning_amber_rounded),
                              label: Text(canSendSos ? 'SOS' : 'SOS bloqueado'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _LatestMessages(channelId: channel.id),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.channel});

  final EventChannel channel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.name.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                channel.description ?? 'Canal operativo del evento.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        PriorityBadge(isEmergency: channel.isEmergency),
      ],
    );
  }
}

class _BroadcastTargetSelector extends StatelessWidget {
  const _BroadcastTargetSelector({
    required this.broadcastAll,
    required this.totalChannels,
    required this.onChanged,
  });

  final bool broadcastAll;
  final int totalChannels;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Destino de transmision',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                const ButtonSegment<bool>(
                  value: false,
                  label: Text('Canal actual'),
                  icon: Icon(Icons.radio),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Todos ($totalChannels)'),
                  icon: const Icon(Icons.campaign),
                ),
              ],
              selected: {broadcastAll},
              onSelectionChanged: (selection) {
                onChanged(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioConnectionStatus extends StatelessWidget {
  const _AudioConnectionStatus({
    required this.isPreparing,
    required this.isReady,
    required this.error,
    required this.canListen,
    required this.canOperate,
  });

  final bool isPreparing;
  final bool isReady;
  final String? error;
  final bool canListen;
  final bool canOperate;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String label;

    if (!canOperate) {
      icon = Icons.lock_outline;
      color = Colors.white54;
      label = 'Audio bloqueado: evento no operativo';
    } else if (!canListen) {
      icon = Icons.hearing_disabled_outlined;
      color = Colors.white54;
      label = 'Sin permiso de escucha en este canal';
    } else if (isPreparing) {
      icon = Icons.sync;
      color = Colors.orangeAccent;
      label = 'Conectando escucha LiveKit...';
    } else if (error != null) {
      icon = Icons.error_outline;
      color = Colors.redAccent;
      label = error!;
    } else if (isReady) {
      icon = Icons.hearing_outlined;
      color = Colors.greenAccent;
      label = 'Escuchando canal';
    } else {
      icon = Icons.radio_outlined;
      color = Colors.white70;
      label = 'Escucha lista para conectar';
    }

    return DecoratedBox(
      decoration: AppTheme.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestMessages extends ConsumerWidget {
  const _LatestMessages({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesState = ref.watch(voiceMessagesProvider(channelId));

    return messagesState.when(
      data: (messages) {
        if (messages.isEmpty) {
          return DecoratedBox(
            decoration: AppTheme.panelDecoration(),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Todavia no hay mensajes en este canal.'),
            ),
          );
        }

        return DecoratedBox(
          decoration: AppTheme.panelDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ultimos audios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...messages.take(3).map((message) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: message.isPriority
                                  ? AppTheme.danger
                                  : AppTheme.accent,
                            ),
                          ),
                          child: Icon(
                            message.isPriority
                                ? Icons.priority_high
                                : Icons.play_arrow,
                            color: message.isPriority
                                ? AppTheme.danger
                                : AppTheme.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${message.senderName}: ${_messageSummary(message)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => DecoratedBox(
        decoration: AppTheme.panelDecoration(),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No pudimos cargar el historial.'),
        ),
      ),
    );
  }
}

String _messageSummary(VoiceMessage message) {
  final transcription = message.transcription;
  if (transcription != null && transcription.trim().isNotEmpty) {
    return transcription;
  }
  return message.isPriority
      ? 'Alerta SOS registrada'
      : 'Audio simulado guardado';
}

class _ChannelPresenceBar extends ConsumerWidget {
  const _ChannelPresenceBar({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.watch(audioRoomServiceProvider);
    return StreamBuilder<AudioRoomState>(
      stream: audioService.stateChanges,
      initialData: audioService.state,
      builder: (context, snapshot) {
        final presence = snapshot.data?.forChannel(channelId);
        if (presence == null || !presence.isConnected) {
          return const SizedBox.shrink();
        }

        final speakingLabel = presence.someoneSpeaking
            ? 'Hablando: ${presence.speakingNames.join(', ')}'
            : 'Nadie esta hablando ahora';

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DecoratedBox(
            decoration: AppTheme.panelDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    presence.someoneSpeaking
                        ? Icons.record_voice_over
                        : Icons.headset_mic_outlined,
                    size: 20,
                    color: presence.someoneSpeaking
                        ? Colors.redAccent
                        : Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${presence.participantCount} en el canal',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          speakingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
