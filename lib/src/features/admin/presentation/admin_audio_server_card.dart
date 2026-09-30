import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/audio/audio_server_controller.dart';
import 'package:event_radio_app/src/shared/audio/audio_server_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permite apuntar el audio a un servidor LiveKit de la red del predio.
///
/// Pensado para eventos donde internet no es confiable: con un servidor
/// local, el PTT sigue funcionando aunque se caiga el enlace, y los
/// mensajes quedan en la cola de reenvio hasta que vuelva.
///
/// La configuracion se guarda en el dispositivo, no en el backend: es
/// justamente lo que hay que poder cambiar cuando el backend no se alcanza.
class AdminAudioServerCard extends ConsumerStatefulWidget {
  /// Crea la tarjeta.
  const AdminAudioServerCard({super.key});

  @override
  ConsumerState<AdminAudioServerCard> createState() =>
      _AdminAudioServerCardState();
}

class _AdminAudioServerCardState extends ConsumerState<AdminAudioServerCard> {
  final _controller = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _messageFor(AudioServerUrlIssue issue, AppLocalizations l10n) {
    return switch (issue) {
      AudioServerUrlIssue.empty => l10n.audioServerErrorEmpty,
      AudioServerUrlIssue.wrongScheme => l10n.audioServerErrorScheme,
      AudioServerUrlIssue.malformed ||
      AudioServerUrlIssue.missingHost =>
        l10n.audioServerErrorMalformed,
    };
  }

  Future<void> _useLocal() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final issue = await ref
        .read(audioServerProvider.notifier)
        .useLocalServer(_controller.text);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _error = issue == null ? null : _messageFor(issue, l10n);
    });
  }

  Future<void> _useCloud() async {
    await ref.read(audioServerProvider.notifier).useCloudServer();
    if (!mounted) return;
    _controller.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setting = ref.watch(audioServerProvider);
    final isLocal = setting.usesLocalServer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLocal ? Icons.lan_outlined : Icons.cloud_outlined,
                  color: isLocal ? AppTheme.success : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.audioServerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isLocal
                  ? l10n.audioServerUsingLocal(setting.localUrl!)
                  : l10n.audioServerUsingCloud,
              style: TextStyle(
                color: isLocal ? AppTheme.success : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isLocal ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.audioServerHelp,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_isSaving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.audioServerFieldLabel,
                hintText: 'ws://192.168.1.50:7880',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _useLocal,
                    icon: const Icon(Icons.lan_outlined, size: 18),
                    label: Text(l10n.audioServerUseLocal),
                  ),
                ),
                if (isLocal) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _useCloud,
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: Text(l10n.audioServerUseCloud),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
