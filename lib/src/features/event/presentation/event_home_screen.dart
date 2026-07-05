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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.accent,
          duration: const Duration(seconds: 6),
          content: Text(
            'SOS recibido en $channelName',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    });

    return AppScaffold(
      title: 'Handy',
      actions: [
        IconButton(
          tooltip: 'Bitacora',
          onPressed: () => context.push('/admin'),
          icon: const Icon(Icons.assignment_outlined),
        ),
        const LeaveEventAction(),
      ],
      child: SessionGuard(
        builder: (context, session) {
          final canOperate = session.event.isOperational(DateTime.now());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EventHeader(session: session),
              if (!canOperate) ...[
                const SizedBox(height: 12),
                const _EventNoLongerActiveBanner(),
              ],
              const SizedBox(height: 20),
              Text(
                canOperate ? 'Canales asignados' : 'Canales e historial',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...session.orderedChannels.map(
                (channel) => _ChannelTile(session: session, channel: channel),
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
    final formatter = DateFormat('HH:mm');
    final canOperate = session.event.isOperational(DateTime.now());
    final remaining = session.event.endsAt.difference(DateTime.now());
    final remainingText = remaining.isNegative
        ? 'Finalizado'
        : '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m restantes';
    final statusLabel = canOperate ? 'EN CURSO' : 'BLOQUEADO';
    final statusColor = canOperate ? AppTheme.success : AppTheme.warning;
    final statusIcon = canOperate ? Icons.circle : Icons.lock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  label: statusLabel,
                  color: statusColor,
                  icon: statusIcon,
                ),
                Text(
                  remainingText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              session.event.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Operador: ${session.participant.displayName}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              '${formatter.format(session.event.startsAt)} - ${formatter.format(session.event.endsAt)}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniMetric(
                  icon: Icons.radio,
                  label: '${session.channels.length} canales',
                ),
                _MiniMetric(
                  icon: Icons.groups_outlined,
                  label: '${session.participants.length} usuarios',
                ),
                _MiniMetric(
                  icon: Icons.shield_outlined,
                  label: session.participant.role.value,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.session,
    required this.channel,
  });

  final EventSession session;
  final EventChannel channel;

  @override
  Widget build(BuildContext context) {
    final permission = session.permissionFor(channel.id);
    final canOperate = session.event.isOperational(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push('/channel/${channel.id}'),
        leading: CircleAvatar(
          backgroundColor:
              channel.isEmergency ? AppTheme.accent : AppTheme.surfaceRaised,
          child: Icon(
            channel.isEmergency ? Icons.priority_high : Icons.radio,
            color: Colors.white,
          ),
        ),
        title: Text(channel.name),
        subtitle: Text(
          !canOperate
              ? 'Historial disponible · PTT bloqueado'
              : permission?.canTalk == true
                  ? 'Escucha y transmision habilitadas'
                  : 'Solo escucha',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permission?.canTalk == true && canOperate)
              const Icon(
                Icons.mic,
                color: AppTheme.success,
                size: 18,
              ),
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
    return Card(
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
                    'El evento ya no esta operativo.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'La transmision queda bloqueada, pero podés entrar a cada canal para consultar historial.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
