import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/data/session_realtime.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:event_radio_app/src/shared/presentation/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EventHomeScreen extends ConsumerWidget {
  const EventHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activa la sincronizacion realtime del evento y escucha alertas SOS.
    ref.watch(sessionRealtimeProvider);
    ref.listen(sosAlertsProvider, (previous, next) {
      final alert = next.valueOrNull;
      if (alert == null) return;
      final session = ref.read(currentSessionProvider).valueOrNull;
      final channelName =
          session?.channelById(alert.channelId)?.name ?? 'un canal';
      HapticFeedback.vibrate();
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          duration: const Duration(seconds: 6),
          content: Text(
            l10n.sosReceived(channelName),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    });

    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.eventActiveTitle,
      actions: [
        IconButton(
          tooltip: l10n.eventLogButton,
          onPressed: () => context.push('/admin'),
          icon: const Icon(Icons.assignment_outlined),
        ),
        const LeaveEventAction(),
      ],
      child: SessionGuard(
        builder: (context, session) {
          final canOperate = session.event.isOperational(DateTime.now());

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventHeader(session: session),
                      if (!canOperate) ...[
                        const SizedBox(height: 12),
                        const _EventNoLongerActiveBanner(),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        canOperate
                            ? l10n.eventAssignedChannels
                            : l10n.eventChannelsAndHistory,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...session.orderedChannels.map(
                        (channel) =>
                            _ChannelTile(session: session, channel: channel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.session});

  final EventSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat('HH:mm');
    final canOperate = session.event.isOperational(DateTime.now());
    final remaining = session.event.endsAt.difference(DateTime.now());
    final remainingText = remaining.isNegative
        ? l10n.eventFinished
        : l10n.eventTimeRemaining(
            remaining.inHours,
            remaining.inMinutes.remainder(60),
          );
    final statusLabel = canOperate ? l10n.eventOngoing : l10n.eventBlocked;
    final statusColor = canOperate ? AppTheme.success : AppTheme.warning;
    final statusIcon = canOperate ? Icons.circle : Icons.lock;

    return DecoratedBox(
      decoration: AppTheme.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.event.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.eventOperator(session.participant.displayName),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: statusLabel,
                  color: statusColor,
                  icon: statusIcon,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  remainingText,
                  style: TextStyle(
                    color: canOperate ? AppTheme.success : AppTheme.warning,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${formatter.format(session.event.startsAt)} - ${formatter.format(session.event.endsAt)}',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.session, required this.channel});

  final EventSession session;
  final EventChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permission = session.permissionFor(channel.id);
    final canOperate = session.event.isOperational(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push('/channel/${channel.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: channel.isEmergency
                ? AppTheme.danger.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: channel.isEmergency
                  ? AppTheme.danger
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            channel.isEmergency ? Icons.priority_high : Icons.radio,
            color: Colors.white,
          ),
        ),
        title: Text(
          channel.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.description ??
                    (channel.isEmergency
                        ? l10n.eventEmergencyOnly
                        : l10n.eventGeneralCoordination),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  // Decorativo: el texto adyacente ya describe el estado.
                  ExcludeSemantics(
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: canOperate ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !canOperate
                        ? l10n.eventPttBlocked
                        : permission?.canTalk == true
                            ? l10n.eventOperational
                            : l10n.eventListenOnly,
                    style: TextStyle(
                      color: canOperate ? AppTheme.success : AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permission?.canTalk == true && canOperate)
              const Icon(Icons.mic, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _EventNoLongerActiveBanner extends StatelessWidget {
  const _EventNoLongerActiveBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppTheme.panelDecoration(
        borderColor: AppTheme.warning.withValues(alpha: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy, color: AppTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).eventNoLongerActive,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).eventNoLongerActiveDetail,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
