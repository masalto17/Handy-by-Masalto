import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:event_radio_app/src/shared/presentation/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EventClosedScreen extends ConsumerWidget {
  const EventClosedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.eventClosedTitle,
      actions: const [LeaveEventAction()],
      child: SessionGuard(
        builder: (context, session) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.event_busy, size: 72, color: AppTheme.warning),
              const SizedBox(height: 18),
              Text(
                session.event.name,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: StatusPill(
                  label: l10n.pttBlocked,
                  color: AppTheme.warning,
                  icon: Icons.lock,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.eventClosedTransmissionBlocked,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.eventClosedSchedule(
                          DateFormat('dd/MM HH:mm').format(session.event.endsAt),
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.eventClosedHistoryAvailable,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/event'),
                icon: const Icon(Icons.history),
                label: Text(l10n.eventClosedViewHistory),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => leaveEventAndAccount(context, ref),
                icon: const Icon(Icons.logout),
                label: Text(l10n.eventClosedLeave),
              ),
            ],
          );
        },
      ),
    );
  }
}
