import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/auth/data/account_providers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Limpia la sesion y la cuenta, luego navega a la pantalla de ingreso.
///
/// Para invitados anonimos no cierra la sesion de auth (su identidad esta
/// vinculada al codigo de invitacion). Para cuentas reales (Google/email)
/// cierra completamente para permitir cambiar de cuenta.
Future<void> leaveEventAndAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final account = ref.read(accountProvider).valueOrNull;
  final shouldSignOut = account != null && !account.isGuest;
  ref.read(currentSessionProvider.notifier).clear();
  await ref.read(accountProvider.notifier).clear(signOut: shouldSignOut);
  if (!context.mounted) return;
  context.go('/');
}

/// Muestra un dialogo de confirmacion antes de salir del evento.
///
/// Devuelve `true` si el usuario confirmo, `false` si cancelo.
Future<bool> confirmLeaveEvent(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.leaveEventConfirmTitle),
      content: Text(l10n.leaveEventConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.leaveEventConfirmButton),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Boton de accion que sale del evento con dialogo de confirmacion.
class LeaveEventAction extends ConsumerWidget {
  const LeaveEventAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: AppLocalizations.of(context).leaveEventTooltip,
      onPressed: () async {
        final confirmed = await confirmLeaveEvent(context);
        if (confirmed && context.mounted) {
          await leaveEventAndAccount(context, ref);
        }
      },
      icon: const Icon(Icons.logout),
    );
  }
}
