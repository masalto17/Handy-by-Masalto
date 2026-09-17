import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/audio/audio_room_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aviso de que esta instalacion no transmite audio en vivo.
///
/// Sin este aviso, una app sin LiveKit configurado cae al servicio mock y
/// el PTT *parece* funcionar: el operador ve el boton en "transmitiendo",
/// habla, y no lo escucha nadie. Preferimos decirlo de entrada y aclarar
/// que el historial y el SOS si funcionan, para que el operador sepa con
/// que cuenta realmente.
class AudioModeBanner extends ConsumerWidget {
  /// Crea el aviso.
  const AudioModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(audioModeProvider);
    if (mode.transmits) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isDemo = mode == AudioMode.simulated;
    final color = isDemo ? AppTheme.textTertiary : AppTheme.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(
          borderColor: color.withValues(alpha: 0.55),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDemo ? Icons.science_outlined : Icons.mic_off_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDemo
                          ? l10n.audioModeSimulatedTitle
                          : l10n.audioModeUnavailableTitle,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDemo
                          ? l10n.audioModeSimulatedDetail
                          : l10n.audioModeUnavailableDetail,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
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
  }
}
