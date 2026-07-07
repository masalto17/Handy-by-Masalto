import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({required this.channelId, super.key});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'HISTORIAL',
      actions: const [LeaveEventAction()],
      child: SessionGuard(
        builder: (context, session) {
          final channel = session.channelById(channelId);
          if (channel == null) {
            return const Center(child: Text('Canal no asignado.'));
          }

          final permission = session.permissionFor(channel.id);
          if (permission?.canViewHistory == false) {
            return const Center(
              child: Text('No tenes permiso para ver este historial.'),
            );
          }

          final messagesState = ref.watch(voiceMessagesProvider(channel.id));

          return messagesState.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: DecoratedBox(
                    decoration: AppTheme.panelDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Sin mensajes en ${channel.name}.'),
                    ),
                  ),
                );
              }

              final hasPendingAudio = messages.any(
                (message) =>
                    message.hasAudio &&
                    (message.transcriptionStatus ==
                            TranscriptionStatus.pending ||
                        message.transcriptionStatus ==
                            TranscriptionStatus.failed),
              );

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                itemCount: messages.length + (hasPendingAudio ? 1 : 0),
                itemBuilder: (context, index) {
                  if (hasPendingAudio && index == 0) {
                    return _TranscriptionAction(channelId: channel.id);
                  }
                  final messageIndex = index - (hasPendingAudio ? 1 : 0);
                  return _VoiceMessageTile(message: messages[messageIndex]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('No pudimos cargar el historial.')),
          );
        },
      ),
    );
  }
}

class _TranscriptionAction extends ConsumerStatefulWidget {
  const _TranscriptionAction({required this.channelId});

  final String channelId;

  @override
  ConsumerState<_TranscriptionAction> createState() =>
      _TranscriptionActionState();
}

class _TranscriptionActionState extends ConsumerState<_TranscriptionAction> {
  bool _isProcessing = false;

  Future<void> _transcribe() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final count = await ref
          .read(eventRadioRepositoryProvider)
          .transcribePendingMessages(widget.channelId);
      ref.invalidate(voiceMessagesProvider(widget.channelId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No habia audios pendientes para transcribir.'
                : 'Transcripciones actualizadas: $count.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos transcribir: ${_cleanError(error)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(
          borderColor: AppTheme.accent.withValues(alpha: 0.44),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.text_snippet_outlined, color: AppTheme.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Hay audios pendientes de transcripcion.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _transcribe,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isProcessing ? 'Procesando' : 'Transcribir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceMessageTile extends ConsumerStatefulWidget {
  const _VoiceMessageTile({required this.message});

  final VoiceMessage message;

  @override
  ConsumerState<_VoiceMessageTile> createState() => _VoiceMessageTileState();
}

class _VoiceMessageTileState extends ConsumerState<_VoiceMessageTile> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  bool _isLoading = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_completeSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;

    if (_isPlaying) {
      await _player.stop();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = await ref
          .read(eventRadioRepositoryProvider)
          .getVoiceMessageAudioUrl(widget.message);

      if (url == null || url.trim().isEmpty) {
        throw StateError('Audio no disponible.');
      }

      await _player.play(UrlSource(url, mimeType: 'audio/wav'));

      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos reproducir este audio.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(
          borderColor: message.isPriority
              ? AppTheme.danger.withValues(alpha: 0.52)
              : AppTheme.surfaceBorder,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: message.isPriority ? AppTheme.danger : AppTheme.accent,
                width: 2,
              ),
            ),
            child: Icon(
              message.isPriority ? Icons.priority_high : Icons.play_arrow,
              color: message.isPriority ? AppTheme.danger : AppTheme.accent,
            ),
          ),
          title: Text(
            message.senderName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _messageSummary(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _WaveformPreview(
                color: message.isPriority ? AppTheme.danger : Colors.white70,
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: const TextStyle(color: Colors.white54),
              ),
              if (message.hasAudio) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: _isPlaying ? 'Detener audio' : 'Reproducir audio',
                  onPressed: _togglePlayback,
                  color: _isPlaying ? AppTheme.accent : Colors.white,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformPreview extends StatelessWidget {
  const _WaveformPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = <double>[8, 14, 18, 10, 16, 22, 12, 20, 15, 24, 12, 18];

    return SizedBox(
      height: 24,
      child: Row(
        children: [
          for (final height in heights) ...[
            Container(
              width: 2,
              height: height,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

String _messageSummary(VoiceMessage message) {
  final transcription = message.transcription;
  if (transcription != null && transcription.trim().isNotEmpty) {
    return transcription;
  }
  if (message.transcriptionStatus == TranscriptionStatus.pending) {
    return 'Transcripcion pendiente';
  }
  if (message.transcriptionStatus == TranscriptionStatus.queued) {
    return 'Transcripcion en cola';
  }
  if (message.transcriptionStatus == TranscriptionStatus.processing) {
    return 'Transcripcion en proceso';
  }
  if (message.transcriptionStatus == TranscriptionStatus.failed) {
    return 'Transcripcion fallida. Revisar configuracion.';
  }
  return message.isPriority ? 'Alerta SOS registrada' : 'Audio guardado';
}

String _cleanError(Object error) {
  final message = error.toString();
  return message
      .replaceFirst('FunctionException', 'Funcion')
      .replaceFirst('Exception:', '')
      .trim();
}
