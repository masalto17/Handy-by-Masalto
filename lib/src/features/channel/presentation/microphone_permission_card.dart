import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/audio/microphone_readiness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aviso de que falta el permiso de microfono, con la accion para resolverlo.
///
/// Aparece al entrar al canal, no al apretar PTT: la idea es que el
/// operador arregle el permiso con tiempo y no descubra el problema en el
/// momento en que necesitaba hablar.
class MicrophonePermissionCard extends ConsumerWidget {
  /// Crea el aviso.
  const MicrophonePermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(microphoneReadinessProvider);
    if (!readiness.needsAttention) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final controller = ref.read(microphoneReadinessProvider.notifier);
    final isBlocked = readiness == MicrophoneReadiness.blocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(
          borderColor: AppTheme.warning.withValues(alpha: 0.55),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mic_none,
                    color: AppTheme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.micPermissionTitle,
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isBlocked
                    ? l10n.micPermissionBlockedDetail
                    : l10n.micPermissionDetail,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: isBlocked
                      ? controller.openSettings
                      : controller.request,
                  icon: Icon(isBlocked ? Icons.settings : Icons.mic),
                  label: Text(
                    isBlocked
                        ? l10n.micPermissionOpenSettings
                        : l10n.micPermissionGrant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
