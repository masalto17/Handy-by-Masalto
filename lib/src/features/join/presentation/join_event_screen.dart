import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/auth/data/account_providers.dart';
import 'package:event_radio_app/src/features/auth/presentation/account_identity_card.dart';
import 'package:event_radio_app/src/features/join/presentation/create_event_dialog.dart';
import 'package:event_radio_app/src/features/join/presentation/how_it_works_sheet.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinEventScreen extends ConsumerStatefulWidget {
  const JoinEventScreen({super.key});

  @override
  ConsumerState<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends ConsumerState<JoinEventScreen> {
  final _codeController = TextEditingController(
    text: EnvConfig.allowDemoShortcuts ? 'SATI26' : '',
  );
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    await _joinWithCode(_codeController.text);
  }

  Future<void> _createEvent() async {
    final created = await showCreateEventDialog(context);
    if (created == true && mounted) {
      context.go('/event');
    }
  }

  Future<void> _joinAsLocalAdminDemo() async {
    setState(() => _error = null);
    try {
      await ref.read(accountProvider.notifier).continueAsLocalAdminDemo();
      await _joinWithCode('PILOTOADMIN123');
    } catch (_) {
      setState(() => _error = 'No pudimos ingresar como admin demo.');
    }
  }

  Future<void> _joinWithCode(String code) async {
    setState(() => _error = null);
    try {
      final session =
          await ref.read(currentSessionProvider.notifier).joinByCode(code);
      if (!mounted) return;

      if (session.event.isOperational(DateTime.now())) {
        context.go('/event');
      } else {
        context.go('/closed');
      }
    } on JoinEventException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'No pudimos ingresar al evento.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(currentSessionProvider);
    final isLoading = sessionState.isLoading;

    return AppScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            const _JoinBrandHeader(),
            const SizedBox(height: 42),
            Text(
              'Ingresar a un evento',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa el codigo o QR que te compartio el coordinador.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            const AccountIdentityCard(),
            const SizedBox(height: 16),
            if (EnvConfig.allowDemoShortcuts &&
                EnvConfig.isSupabaseAvailable &&
                EnvConfig.isLocalSupabase) ...[
              OutlinedButton.icon(
                onPressed: isLoading ? null : _joinAsLocalAdminDemo,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Ingresar como admin demo'),
              ),
              const SizedBox(height: 16),
            ],
            _InviteCodePanel(
              controller: _codeController,
              error: _error,
              onSubmitted: isLoading ? null : _join,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _join,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(isLoading ? 'Validando...' : 'Ingresar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear QR'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => showHowItWorksSheet(context),
              icon: const Icon(Icons.help_outline, size: 18),
              label: Text(AppLocalizations.of(context).howItWorks),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('O', style: TextStyle(color: Colors.white54)),
                ),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _createEvent,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Sos organizador? Crea tu evento'),
            ),
            if (EnvConfig.allowDemoShortcuts) ...[
              const SizedBox(height: 24),
              const _DemoCodesCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemoCodesCard extends StatelessWidget {
  const _DemoCodesCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Codigos demo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text('SATI26: evento activo'),
            Text('MARCOS26: participante seguridad'),
            Text('ANA26: participante produccion'),
            Text('JULIA26: coordinadora tecnica'),
            Text('CERRADO: evento finalizado'),
          ],
        ),
      ),
    );
  }
}

class _JoinBrandHeader extends StatelessWidget {
  const _JoinBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.brandGold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.brandGold.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGold.withValues(alpha: 0.18),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(Icons.settings_remote_outlined,
              color: AppTheme.brandGold),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HANDY',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 4.0,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              const Text(
                'by MASALTO · radio operativa para eventos',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.brandGold,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteCodePanel extends StatelessWidget {
  const _InviteCodePanel({
    required this.controller,
    required this.error,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface.withValues(alpha: 0.86),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppTheme.accent,
                  size: 18,
                ),
                Text(
                  'Codigo de invitacion',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Text(
                  'VALIDACION SEGURA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: 'CODIGO',
                errorText: error,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ],
        ),
      ),
    );
  }
}
