import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/auth/data/account_providers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Future<void> leaveEventAndAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final account = ref.read(accountProvider).valueOrNull;
  // Los invitados/participantes usan una sesion anonima que ES la identidad
  // vinculada a su codigo de invitacion: cerrarla del todo invalidaria el
  // codigo para siempre en este dispositivo. Solo se cierra sesion por
  // completo para cuentas reales (Google/email), donde "salir" debe
  // permitir entrar despues con otra cuenta.
  final shouldSignOut = account != null && !account.isGuest;
  ref.read(currentSessionProvider.notifier).clear();
  await ref.read(accountProvider.notifier).clear(signOut: shouldSignOut);
  if (!context.mounted) return;
  context.go('/');
}

class LeaveEventAction extends ConsumerWidget {
  const LeaveEventAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: AppLocalizations.of(context).leaveEventTooltip,
      onPressed: () => leaveEventAndAccount(context, ref),
      icon: const Icon(Icons.logout),
    );
  }
}
