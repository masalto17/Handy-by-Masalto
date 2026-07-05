import 'package:event_radio_app/src/features/auth/data/account_providers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

Future<void> leaveEventAndAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.read(currentSessionProvider.notifier).clear();
  await ref.read(accountProvider.notifier).clear();
  if (!context.mounted) return;
  context.go('/');
}

class LeaveEventAction extends ConsumerWidget {
  const LeaveEventAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Salir / cambiar usuario',
      onPressed: () => leaveEventAndAccount(context, ref),
      icon: const Icon(Icons.logout),
    );
  }
}
