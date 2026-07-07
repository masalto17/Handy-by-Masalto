import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    super.key,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: AppTheme.accent),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            const _RuntimeModeBanner(),
            Expanded(
              child: DecoratedBox(
                decoration: AppTheme.screenDecoration(),
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class _RuntimeModeBanner extends StatelessWidget {
  const _RuntimeModeBanner();

  @override
  Widget build(BuildContext context) {
    final isRealMode = EnvConfig.isSupabaseAvailable;
    final color = isRealMode ? AppTheme.success : Colors.amberAccent;
    final label = isRealMode
        ? 'MODO REAL - Supabase configurado'
        : 'MODO MOCK - datos locales para demo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
