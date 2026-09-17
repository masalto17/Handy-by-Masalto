import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/audio/ptt_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aviso visible de mensajes PTT que todavia no quedaron guardados.
///
/// Un operador no puede quedarse con la duda de si lo que dijo llego o no.
/// Mientras haya pendientes se muestra el estado; si se agotaron los
/// reintentos automaticos ofrece reintentar a mano.
class PttOutboxBanner extends ConsumerWidget {
  /// Crea el aviso.
  const PttOutboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pttOutboxProvider);
    if (pending.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final failed = pending
        .where((message) => message.status == PttDeliveryStatus.failed)
        .length;
    final inFlight = pending.length - failed;
    final hasFailures = failed > 0;

    final color = hasFailures ? AppTheme.danger : AppTheme.warning;
    final label = hasFailures
        ? l10n.pttOutboxFailed(failed)
        : l10n.pttOutboxPending(inFlight);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: AppTheme.panelDecoration(
          borderColor: color.withValues(alpha: 0.55),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                hasFailures ? Icons.error_outline : Icons.cloud_upload_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              if (hasFailures)
                TextButton(
                  onPressed: () =>
                      ref.read(pttOutboxProvider.notifier).retryFailed(),
                  child: Text(l10n.pttOutboxRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
