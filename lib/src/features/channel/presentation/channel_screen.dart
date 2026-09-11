import 'dart:async';

import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/channel/presentation/push_to_talk_button.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/data/session_realtime.dart';
import 'package:event_radio_app/src/shared/domain/app_exceptions.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/error_localizer.dart';
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
  StreamSubscription<ReconnectionFailure>? _reconnectionSub;

  @override
  void initState() {
    super.initState();
    // Se captura aca porque "ref" no puede usarse dentro de dispose().
    _audioService = ref.read(audioRoomServiceProvider);
    // Dentro de un canal la pantalla no debe bloquearse: el operador tiene
    // que poder escuchar y responder al instante durante todo el evento.
    // El catchError cubre plataformas sin soporte (y los widget tests).
    unawaited(WakelockPlus.enable().catchError((_) {}));

    // Escuchar fallos de reconexion para mostrar aviso visible al operador.
    _reconnectionSub = _audioService.reconnectionFailures.listen((failure) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (failure.channelId == widget.channelId) {
        setState(() {
          _audioReady = false;
          _audioError = l10n.channelReconnectError(
            failure.channelName,
            failure.attempts,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(l10n.channelReconnectSnack(failure.channelName)),
          action: SnackBarAction(
            label: l10n.channelReconnectRetry,
            onPressed: () {
              // Resetear el estado para que prepareListening intente de nuevo.
              setState(() {
                _preparedChannelId = null;
                _audioError = null;
              });
            },
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _reconnectionSub?.cancel();
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
        _audioError = AppLocalizations.of(context).channelConnectError;
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sosActivated(channel.name))),
      );
    } on EventOperationException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorLocalizer.operationError(l10n, error))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).sosError)),
      );
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

    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.channelTitle,
      actions: const [LeaveEventAction()],
      child: SessionGuard(
        builder: (context, session) {
          final channel = session.channelById(widget.channelId);
          if (channel == null) {
            return Center(child: Text(l10n.channelNotAssigned));
          }

          final permission = session.permissionFor(channel.id);
          final canOperate = session.event.isOperational(DateTime.now());
          final canListen = permission?.canListen ?? false;
          final canBroadcast =
              session.participant.canAccessAdmin && session.channels.length > 1;
          final targetChannels =
              _broadcastAll && canBroadcast ? session.channels : [channel];
          final destinationLabel = _broadcastAll && canBroadcast
              ? l10n.channelAllChannels
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
                              label: Text(l10n.history),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              button: true,
                              enabled: canSendSos && !_isSendingSos,
                              label: _isSendingSos
                                  ? l10n.a11ySosButtonSending
                                  : l10n.a11ySosEmergency,
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
                                  side:
                                      const BorderSide(color: AppTheme.danger),
                                ),
                                icon: _isSendingSos
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.warning_amber_rounded),
                                label: Text(
                                  canSendSos ? l10n.sosLabel : l10n.sosBlocked,
                                ),
                              ),
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
                channel.description ??
                    AppLocalizations.of(context).channelDefaultDescription,
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
              AppLocalizations.of(context).channelBroadcastTarget,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(
                    AppLocalizations.of(context).channelCurrentChannel,
                  ),
                  icon: const Icon(Icons.radio),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(
                    AppLocalizations.of(context).channelAllCount(totalChannels),
                  ),
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

    final l10n = AppLocalizations.of(context);
    if (!canOperate) {
      icon = Icons.lock_outline;
      color = Colors.white54;
      label = l10n.channelAudioBlocked;
    } else if (!canListen) {
      icon = Icons.hearing_disabled_outlined;
      color = Colors.white54;
      label = l10n.channelNoListenPermission;
    } else if (isPreparing) {
      icon = Icons.sync;
      color = Colors.orangeAccent;
      label = l10n.channelConnectingLiveKit;
    } else if (error != null) {
      icon = Icons.error_outline;
      color = Colors.redAccent;
      label = error!;
    } else if (isReady) {
      icon = Icons.hearing_outlined;
      color = Colors.greenAccent;
      label = l10n.channelListening;
    } else {
      icon = Icons.radio_outlined;
      color = Colors.white70;
      label = l10n.channelReadyToConnect;
    }

    // El icono es decorativo: el texto ya describe el estado de conexion.
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppLocalizations.of(context).channelNoMessages),
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
                  AppLocalizations.of(context).channelLatestAudios,
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
                            '${message.senderName}: ${_messageSummary(context, message)}',
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(AppLocalizations.of(context).channelHistoryError),
        ),
      ),
    );
  }
}

String _messageSummary(BuildContext context, VoiceMessage message) {
  final transcription = message.transcription;
  if (transcription != null && transcription.trim().isNotEmpty) {
    return transcription;
  }
  final l10n = AppLocalizations.of(context);
  return message.isPriority ? l10n.historySosAlert : l10n.historyAudioSaved;
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

        final l10n = AppLocalizations.of(context);
        final speakingLabel = presence.someoneSpeaking
            ? l10n.channelSpeaking(presence.speakingNames.join(', '))
            : l10n.channelNobodySpeaking;

        // Se agrupa icono + textos en un nodo semantico unico con la
        // informacion de presencia completa.
        final semanticLabel =
            '${l10n.channelPresenceCount(presence.participantCount)}. $speakingLabel';

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            label: semanticLabel,
            child: ExcludeSemantics(
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
                              l10n.channelPresenceCount(
                                presence.participantCount,
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
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
            ),
          ),
        );
      },
    );
  }
}
