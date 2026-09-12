import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Tarjeta con el registro de actividad del evento.
class AdminLogsCard extends ConsumerWidget {
  const AdminLogsCard({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsState = ref.watch(eventLogsProvider(eventId));

    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.adminLogsCard,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            logsState.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Text(l10n.adminLogsEmpty);
                }

                return Column(
                  children: logs.take(6).map((log) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(log.title),
                      subtitle: Text(log.detail ?? log.type),
                      trailing: Text(
                        DateFormat('HH:mm').format(log.createdAt),
                        style: const TextStyle(color: AppTheme.textTertiary),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(l10n.adminLogsError),
            ),
          ],
        ),
      ),
    );
  }
}
