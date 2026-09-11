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
  const JoinEventScreen({this.initialCode, super.key});

  /// Codigo de invitacion pre-cargado desde un deep link o QR.
  final String? initialCode;

  @override
  ConsumerState<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends ConsumerState<JoinEventScreen> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    final prefill = widget.initialCode ??
        (EnvConfig.allowDemoShortcuts ? 'SATI26' : '');
    _codeController = TextEditingController(text: prefill);
    // Si llega un codigo por deep link, iniciar el ingreso automaticamente.
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }
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
      setState(() => _error = AppLocalizations.of(context).joinAdminDemoError);
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
      setState(() => _error = AppLocalizations.of(context).joinError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(currentSessionProvider);
    final isLoading = sessionState.isLoading;

    return AppScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 700;
          final contentWidth = compact
              ? constraints.maxWidth > 478
                  ? 430.0
                  : constraints.maxWidth - 48
              : constraints.maxWidth > 408
                  ? 342.0
                  : constraints.maxWidth - 48;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: constraints.maxHeight > 760 ? 28 : 4),
                    const _JoinBrandHeader(),
                    SizedBox(height: compact ? 12 : 34),
                    Text(
                      AppLocalizations.of(context).joinTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).joinSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const AccountIdentityCard(),
                    const SizedBox(height: 16),
                    _InviteCodePanel(
                      controller: _codeController,
                      error: _error,
                      isLoading: isLoading,
                      onSubmitted: isLoading ? null : _join,
                    ),
                    const SizedBox(height: 18),
                    const _QrDivider(),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/scan'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(AppLocalizations.of(context).scanQr),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => showHowItWorksSheet(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: Text(AppLocalizations.of(context).howItWorks),
                    ),
                    const SizedBox(height: 16),
                    if (EnvConfig.allowDemoShortcuts &&
                        EnvConfig.isSupabaseAvailable &&
                        EnvConfig.isLocalSupabase) ...[
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _joinAsLocalAdminDemo,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(
                          AppLocalizations.of(context).joinAdminDemoButton,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _createEvent,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        AppLocalizations.of(context).joinCreateEventButton,
                      ),
                    ),
                    if (EnvConfig.allowDemoShortcuts) ...[
                      const SizedBox(height: 24),
                      const _DemoCodesCard(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QrDivider extends StatelessWidget {
  const _QrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            AppLocalizations.of(context).joinOrScanQr,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

class _DemoCodesCard extends StatelessWidget {
  const _DemoCodesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.demoCodes,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(l10n.demoCodeActive),
            Text(l10n.demoCodeSecurity),
            Text(l10n.demoCodeProduction),
            Text(l10n.demoCodeTechnical),
            Text(l10n.demoCodeClosed),
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
    final logoSize = MediaQuery.sizeOf(context).height < 700 ? 120.0 : 282.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGold.withValues(alpha: 0.16),
                blurRadius: 38,
              ),
            ],
          ),
          child: Image.asset(
            AppTheme.logoAsset,
            width: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: 'HANDY by MASALTO',
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
    required this.isLoading,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? error;
  final bool isLoading;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.panelDecoration(glow: true),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).joinInviteCodeLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'SATI26',
                errorText: error,
                suffixIcon: const Icon(Icons.qr_code_2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onSubmitted,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                isLoading
                    ? AppLocalizations.of(context).joinValidating
                    : AppLocalizations.of(context).joinButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
