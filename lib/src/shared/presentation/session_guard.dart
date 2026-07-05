import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionGuard extends ConsumerWidget {
  const SessionGuard({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext context, EventSession session) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(currentSessionProvider);

    return sessionState.when(
      data: (session) {
        if (session == null) {
          return _NoSession(onReturn: () => context.go('/'));
        }
        return builder(context, session);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _NoSession(onReturn: () => context.go('/')),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'No hay evento activo en este dispositivo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onReturn,
              child: const Text('Ingresar con codigo'),
            ),
          ],
        ),
      ),
    );
  }
}
