import 'dart:async';

import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
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
  bool _isTransmitting = false;
  bool _isSaving = false;
  DateTime? _startedAt;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  final PttAudioRecorder _recorder = PttAudioRecorder();
  final LiveSpeechTranscriber _transcriber = LiveSpeechTranscriber();

  @override
  void dispose() {
    _ticker?.cancel();
    if (_isTransmitting) {
      unawaited(ref.read(audioRoomServiceProvider).stopPushToTalk());
      unawaited(_recorder.stop());
      unawaited(_transcriber.stop());
    }
    unawaited(_recorder.dispose());
    unawaited(_transcriber.dispose());
    super.dispose();
  }

  Future<void> _startTransmit() async {
    if (!widget.canTalk || _isSaving || _isTransmitting) return;

    // Confirmacion tactil tipo handie: se siente cuando abre y cierra el
    // canal aunque no se este mirando la pantalla.
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _isTransmitting = true;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
      });
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
      try {
        await _recorder.start();
      } catch (_) {
        // Live audio remains the priority. Recording failures should not stop
        // a live PTT transmission.
      }
    } catch (_) {
      _ticker?.cancel();
      if (!mounted) return;
      setState(() {
        _isTransmitting = false;
        _startedAt = null;
        _elapsedSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos iniciar el audio PTT.')),
      );
    }
  }

  Future<void> _stopTransmit() async {
    if (!_isTransmitting || _startedAt == null) return;

    unawaited(HapticFeedback.lightImpact());
    _ticker?.cancel();
    final duration = DateTime.now().difference(_startedAt!).inSeconds;
    final normalizedDuration = duration.clamp(1, 90);

    setState(() {
      _isTransmitting = false;
      _isSaving = true;
      _elapsedSeconds = normalizedDuration;
    });

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !audioWasSaved
                ? 'PTT registrado en ${widget.destinationLabel}; no se pudo guardar audio.'
                : textWasSaved
                    ? 'Audio y texto guardados en ${widget.destinationLabel}.'
                    : 'Audio guardado. Transcripcion automatica en proceso.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos guardar el PTT.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _startedAt = null;
          _elapsedSeconds = 0;
        });
      }
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
    final compact = MediaQuery.sizeOf(context).height < 720;
    final controlSize = compact ? 168.0 : 244.0;
    final iconSize = compact ? 58.0 : 82.0;
    final color = _isTransmitting
        ? AppTheme.accent
        : widget.canTalk
            ? AppTheme.backgroundRaised
            : AppTheme.background;
    final borderColor = _isTransmitting
        ? AppTheme.accent
        : widget.canTalk
            ? AppTheme.accent
            : Colors.white24;
    final statusLabel = _isSaving
        ? 'GUARDANDO'
        : _isTransmitting
            ? 'TRANSMITIENDO ${_elapsedSeconds}s'
            : widget.canTalk
                ? 'MANTENER PARA HABLAR'
                : 'TRANSMISION BLOQUEADA';

    return Column(
      children: [
        Semantics(
          button: true,
          enabled: widget.canTalk && !_isSaving,
          label: _isTransmitting
              ? 'Transmitiendo. Solta para terminar.'
              : widget.canTalk
                  ? 'Boton para hablar. Manten presionado mientras hablas.'
                  : 'Transmision bloqueada en este canal.',
          child: GestureDetector(
            key: const Key('ptt-button'),
            onTapDown: (_) => _startTransmit(),
            onTapUp: (_) => _stopTransmit(),
            onTapCancel: _stopTransmit,
            child: AnimatedScale(
              scale: _isTransmitting ? 0.96 : 1,
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
                      color: (_isTransmitting ? AppTheme.accent : borderColor)
                          .withValues(alpha: _isTransmitting ? 0.36 : 0.2),
                      blurRadius: _isTransmitting ? 40 : 30,
                      spreadRadius: _isTransmitting ? 7 : 1,
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
                        _isTransmitting
                            ? AppTheme.accent
                            : AppTheme.surfaceRaised,
                        _isTransmitting
                            ? AppTheme.accentSoft
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
                      Icon(
                        _isTransmitting ? Icons.graphic_eq : Icons.mic,
                        size: iconSize,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isTransmitting ? 'AL AIRE' : 'PUSH-TO-TALK',
                        style: TextStyle(
                          color: _isTransmitting
                              ? Colors.black
                              : AppTheme.brandGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (_isTransmitting) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_elapsedSeconds}s',
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
          color: _isTransmitting
              ? AppTheme.accent
              : widget.canTalk
                  ? AppTheme.success
                  : Colors.white54,
          icon: _isTransmitting
              ? Icons.radio_button_checked
              : widget.canTalk
                  ? Icons.touch_app
                  : Icons.lock,
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            widget.canTalk
                ? EnvConfig.hasLiveKitConfig
                    ? 'Destino: ${widget.destinationLabel}. Audio real LiveKit activo; se guarda audio en historial.'
                    : 'Destino: ${widget.destinationLabel}. Audio simulado; LiveKit se activa al configurar credenciales.'
                : 'Tu permiso actual no permite transmitir en este canal.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ],
    );
  }
}
