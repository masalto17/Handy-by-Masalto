import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/auth/data/account_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountIdentityCard extends ConsumerWidget {
  const AccountIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: accountState.when(
          data: (account) {
            if (account == null) {
              return const _UnsignedContent();
            }
            return _SignedContent(
              displayName: account.displayName,
              email: account.email,
              provider: account.provider,
              isGuest: account.isGuest,
              onClear: () => ref.read(accountProvider.notifier).clear(),
            );
          },
          loading: () => const _LoadingContent(),
          error: (_, __) => const Text(
            'No pudimos cargar la cuenta.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _UnsignedContent extends ConsumerWidget {
  const _UnsignedContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocalSupabase = EnvConfig.isSupabaseAvailable &&
        EnvConfig.isLocalSupabase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.account_circle_outlined, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cuenta opcional',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Para el MVP podes entrar solo con codigo. Luego la cuenta servira para recuperar invitaciones y permisos.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLocalSupabase
              ? null
              : () => ref.read(accountProvider.notifier).continueWithGoogle(),
          icon: const Icon(Icons.mail_outline),
          label: Text(
            isLocalSupabase
                ? 'Gmail disponible en staging'
                : 'Continuar con Gmail',
          ),
        ),
        OutlinedButton.icon(
          onPressed: isLocalSupabase
              ? null
              : () => _requestEmailLink(context, ref),
          icon: const Icon(Icons.alternate_email),
          label: Text(
            isLocalSupabase
                ? 'Email disponible en staging'
                : 'Recibir link por email',
          ),
        ),
        TextButton(
          onPressed: () => ref.read(accountProvider.notifier).continueAsGuest(),
          child: const Text('Usar como invitado'),
        ),
      ],
    );
  }

  Future<void> _requestEmailLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingresar con email'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Enviar link'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (email == null || email.trim().isEmpty) return;
    await ref.read(accountProvider.notifier).continueWithEmailLink(email);
  }
}

class _SignedContent extends StatelessWidget {
  const _SignedContent({
    required this.displayName,
    required this.email,
    required this.provider,
    required this.isGuest,
    required this.onClear,
  });

  final String displayName;
  final String? email;
  final String provider;
  final bool isGuest;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final subtitle = isGuest
        ? 'Modo invitado'
        : '${provider.toUpperCase()} · ${email ?? 'sin email'}';

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: isGuest ? Colors.white12 : AppTheme.accent,
          child: Icon(
            isGuest ? Icons.person_outline : Icons.verified_user_outlined,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        TextButton(
          onPressed: onClear,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Preparando cuenta...'),
      ],
    );
  }
}
