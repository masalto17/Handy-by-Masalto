import 'package:event_radio_app/l10n/app_localizations.dart';
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
              onClear: () => ref
                  .read(accountProvider.notifier)
                  .clear(signOut: !account.isGuest),
            );
          },
          loading: () => const _LoadingContent(),
          error: (_, __) => Text(
            AppLocalizations.of(context).accountLoadError,
            style: const TextStyle(color: Colors.white70),
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

    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.account_circle_outlined, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.accountOptional,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.accountMvpInfo,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLocalSupabase
              ? null
              : () => ref.read(accountProvider.notifier).continueWithGoogle(),
          icon: const Icon(Icons.mail_outline),
          label: Text(
            isLocalSupabase
                ? l10n.accountGmailStaging
                : l10n.accountContinueGmail,
          ),
        ),
        OutlinedButton.icon(
          onPressed: isLocalSupabase
              ? null
              : () => _requestEmailLink(context, ref),
          icon: const Icon(Icons.alternate_email),
          label: Text(
            isLocalSupabase
                ? l10n.accountEmailStaging
                : l10n.accountReceiveEmailLink,
          ),
        ),
        TextButton(
          onPressed: () => ref.read(accountProvider.notifier).continueAsGuest(),
          child: Text(l10n.accountUseAsGuest),
        ),
      ],
    );
  }

  Future<void> _requestEmailLink(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.accountEnterWithEmail),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.accountEmailLabel,
              prefixIcon: const Icon(Icons.alternate_email),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.accountCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.accountSendLink),
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
    final l10n = AppLocalizations.of(context);
    final subtitle = isGuest
        ? l10n.accountGuestMode
        : '${provider.toUpperCase()} · ${email ?? l10n.accountNoEmail}';

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
          child: Text(l10n.accountChange),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(AppLocalizations.of(context).accountPreparing),
      ],
    );
  }
}
