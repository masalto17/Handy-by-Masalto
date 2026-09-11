import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/app_bootstrap.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Pantalla de error que se muestra cuando la inicializacion falla en un build
/// de produccion. Impide que el usuario opere sobre datos mock creyendo que
/// esta conectado al backend real.
class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({required this.error, super.key});

  final BootstrapError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.danger,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.bootstrapErrorTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error.message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (error.detail != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error.detail!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                l10n.bootstrapErrorHint,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await AppBootstrap.initialize();
                  if (AppBootstrap.initError == null) {
                    // Reiniciar la app: navegar al inicio si la reconexion
                    // fue exitosa. En Flutter web, esto recarga la pagina.
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.bootstrapErrorRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
