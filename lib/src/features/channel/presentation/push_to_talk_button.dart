import 'dart:async';

import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/channel/domain/ptt_state.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:event_radio_app/src/shared/audio/live_speech_transcriber.dart';
import 'package:event_radio_app/src/shared/audio/ptt_audio_recorder.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PushToTalkButton extends ConsumerStatefulWidget {
  const PushToTalkButton({
    required this.session,
    required this.channels,
    required this.destinationLabel,
    required this.canTalk,
    super.key,
  });

  final EventSession session;
  final List<EventChannel> channels;
  final String destinationLabel;
  final bool canTalk;

  @override
  ConsumerState<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends ConsumerState<PushToTalkButton> {
  PttState _ptt = PttState.idle;
  DateTime? _startedAt;
  Timer? _ticker;
  final PttAudioRecorder _recorder = PttAudioRecorder();
  final LiveSpeechTranscriber _transcriber = LiveSpeechTranscriber();

  void _setPtt(PttState next) {
    if (!mounted) return;
    setState(() => _ptt = next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_ptt.isActive) {
      unawaited(ref.read(audioRoomServiceProvider).stopPushToTalk());
      unawaited(_recorder.stop());
      unawaited(_transcriber.stop());
    }
    unawaited(_recorder.dispose());
    unawaited(_transcriber.dispose());
    super.dispose();
  }

  Future<void> _startTransmit() async {
    if (!widget.canTalk || _ptt.isBusy) return;

    // Confirmacion tactil tipo handie: se siente cuando abre y cierra el
    // canal aunque no se este mirando la pantalla.
    unawaited(HapticFeedback.mediumImpact());

    // --- REQUESTING: el usuario presiono pero el canal no esta confirmado ---
    _setPtt(const PttState(phase: PttPhase.requesting));
    _startedAt = DateTime.now();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      _setPtt(_ptt.copyWith(elapsedSeconds: elapsed));
    });

    try {
      try {
        await _transcriber.start();
      } catch (_) {
        // Browser speech recognition must be started close to the user gesture
        // and is optional.
      }
      await ref
          .read(audioRoomServiceProvider)
          .startPushToTalk(session: widget.session, channels: widget.channels);

      // --- TRANSMITTING: sala confirmada, microfono publicando ---
      unawaited(HapticFeedback.heavyImpact());
      _setPtt(_ptt.copyWith(phase: PttPhase.transmitting));

      try {
        await _recorder.start();
      } catch (_) {
        // Live audio remains the priority. Recording failures should not stop
        // a live PTT transmission.
      }
    } catch (e) {
      _ticker?.cancel();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = e is AudioRoomConfigurationException
          ? e.message
          : l10n.pttAudioStartError;
      _setPtt(PttState(phase: PttPhase.error, errorMessage: message));
      // Volver a idle despues de mostrar el error brevemente.
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted && _ptt.isError) {
          _setPtt(PttState.idle);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _stopTransmit() async {
    if (!_ptt.isActive || _startedAt == null) return;

    unawaited(HapticFeedback.lightImpact());
    _ticker?.cancel();
    final duration = DateTime.now().difference(_startedAt!).inSeconds;
    final normalizedDuration = duration.clamp(1, 90);

    // --- FINALIZING: guardando grabacion e historial ---
    _setPtt(PttState(
      phase: PttPhase.finalizing,
      elapsedSeconds: normalizedDuration,
    ));

    try {
      await ref.read(audioRoomServiceProvider).stopPushToTalk();
      RecordedPttAudio? recordedAudio;
      try {
        recordedAudio = await _recorder.stop();
      } catch (_) {
        recordedAudio = null;
      }
      String? browserTranscript;
      try {
        browserTranscript = await _transcriber.stop();
      } catch (_) {
        browserTranscript = null;
      }
      final sentMessages =
          await ref.read(eventRadioRepositoryProvider).sendPttMessage(
                session: widget.session,
                channels: widget.channels,
                durationSeconds: normalizedDuration,
                audioBytes: recordedAudio?.bytes,
                audioMimeType: recordedAudio?.mimeType,
                browserTranscriptionText: browserTranscript,
              );
      final audioWasSaved = sentMessages.any((message) => message.hasAudio);
      final textWasSaved = sentMessages.any(
        (message) =>
            message.transcriptionStatus == TranscriptionStatus.completed &&
            (message.transcription?.trim().isNotEmpty ?? false),
      );
      for (final channel in widget.channels) {
        ref.invalidate(voiceMessagesProvider(channel.id));
      }
      ref.invalidate(eventLogsProvider(widget.session.event.id));
      _transcribeSavedMessages(sentMessages);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !audioWasSaved
                ? l10n.pttSavedNoAudio(widget.destinationLabel)
                : textWasSaved
                    ? l10n.pttSavedAudioAndText(widget.destinationLabel)
                    : l10n.pttSavedAudioOnly,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pttSaveError)),
      );
    } finally {
      _startedAt = null;
      _setPtt(PttState.idle);
    }
  }

  void _transcribeSavedMessages(List<VoiceMessage> messages) {
    final pendingAudioMessages = messages.where(
      (message) =>
          message.hasAudio &&
          (message.transcriptionStatus == TranscriptionStatus.pending ||
              message.transcriptionStatus == TranscriptionStatus.failed),
    );
    final idsByChannel = <String, List<String>>{};
    for (final message in pendingAudioMessages) {
      idsByChannel.putIfAbsent(message.channelId, () => []).add(message.id);
    }
    if (idsByChannel.isEmpty) return;

    unawaited(
      Future<void>(() async {
        final repository = ref.read(eventRadioRepositoryProvider);
        for (final entry in idsByChannel.entries) {
          try {
            await repository.transcribePendingMessages(
              entry.key,
              messageIds: entry.value,
              limit: entry.value.length,
            );
          } catch (_) {
            // Audio playback remains the source of truth. Failed
            // transcriptions stay visible in history for manual retry.
          } finally {
            if (mounted) {
              ref.invalidate(voiceMessagesProvider(entry.key));
            }
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).height < 720;
    final controlSize = compact ? 168.0 : 244.0;
    final iconSize = compact ? 58.0 : 82.0;

    final isActive = _ptt.isTransmitting;
    final isRequesting = _ptt.isRequesting;
    final isBusy = _ptt.isBusy;

    final color = isActive
        ? AppTheme.accent
        : isRequesting
            ? AppTheme.accent.withValues(alpha: 0.6)
            : widget.canTalk
                ? AppTheme.backgroundRaised
                : AppTheme.background;
    final borderColor = isActive || isRequesting
        ? AppTheme.accent
        : widget.canTalk
            ? AppTheme.accent
            : Colors.white24;
    final statusLabel = _ptt.isError
        ? _ptt.errorMessage ?? l10n.pttError
        : _ptt.isFinalizing
            ? l10n.pttSaving
            : isActive
                ? l10n.pttTransmittingStatus(_ptt.elapsedSeconds)
                : isRequesting
                    ? l10n.pttConnecting
                    : widget.canTalk
                        ? l10n.pttHold
                        : l10n.pttBlocked;

    return Column(
      children: [
        Semantics(
          button: true,
          enabled: widget.canTalk && !isBusy,
          label: isActive
              ? l10n.pttA11yTransmitting
              : isRequesting
                  ? l10n.pttA11yConnecting
                  : widget.canTalk
                      ? l10n.pttA11yReady
                      : l10n.pttA11yBlocked,
          child: GestureDetector(
            key: const Key('ptt-button'),
            onTapDown: (_) => _startTransmit(),
            onTapUp: (_) => _stopTransmit(),
            onTapCancel: _stopTransmit,
            child: AnimatedScale(
              scale: _ptt.isActive ? 0.96 : 1,
              duration: const Duration(milliseconds: 160),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: controlSize,
                height: controlSize,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.85),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? AppTheme.accent : borderColor)
                          .withValues(alpha: isActive ? 0.36 : 0.2),
                      blurRadius: isActive ? 40 : 30,
                      spreadRadius: isActive ? 7 : 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.52),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    gradient: RadialGradient(
                      colors: [
                        isActive
                            ? AppTheme.accent
                            : isRequesting
                                ? AppTheme.accent.withValues(alpha: 0.5)
                                : AppTheme.surfaceRaised,
                        isActive
                            ? AppTheme.accentSoft
                            : isRequesting
                                ? AppTheme.accent.withValues(alpha: 0.2)
                                : AppTheme.background,
                      ],
                    ),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.95),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRequesting)
                        SizedBox(
                          width: iconSize * 0.6,
                          height: iconSize * 0.6,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      else
                        Icon(
                          isActive
                              ? Icons.graphic_eq
                              : _ptt.isError
                                  ? Icons.error_outline
                                  : Icons.mic,
                          size: iconSize,
                          color: _ptt.isError ? AppTheme.danger : Colors.white,
                        ),
                      const SizedBox(height: 14),
                      Text(
                        isActive
                            ? l10n.pttTransmitting
                            : isRequesting
                                ? l10n.pttConnecting
                                : _ptt.isError
                                    ? l10n.pttError
                                    : l10n.pttLabel,
                        style: TextStyle(
                          color: isActive
                              ? Colors.black
                              : _ptt.isError
                                  ? AppTheme.danger
                                  : isRequesting
                                      ? Colors.white70
                                      : AppTheme.brandGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_ptt.elapsedSeconds}s',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        StatusPill(
          label: statusLabel,
          color: _ptt.isError
              ? AppTheme.danger
              : isActive
                  ? AppTheme.accent
                  : isRequesting
                      ? Colors.orangeAccent
                      : widget.canTalk
                          ? AppTheme.success
                          : Colors.white54,
          icon: _ptt.isError
              ? Icons.error_outline
              : isActive
                  ? Icons.radio_button_checked
                  : isRequesting
                      ? Icons.sync
                      : widget.canTalk
                          ? Icons.touch_app
                          : Icons.lock,
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            _ptt.isError
                ? _ptt.errorMessage ?? l10n.pttErrorConnecting
                : widget.canTalk
                    ? EnvConfig.hasLiveKitConfig
                        ? l10n.pttDestinationLiveKit(widget.destinationLabel)
                        : l10n.pttDestinationSimulated(widget.destinationLabel)
                    : l10n.pttNoPermission,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ],
    );
  }
}
