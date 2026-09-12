import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_channels_card.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_event_card.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_logs_card.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_participants_card.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_pilot_card.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminEventScreen extends ConsumerWidget {
  const AdminEventScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.adminTitle,
      actions: [
        IconButton(
          tooltip: l10n.adminInviteQrTooltip,
          onPressed: () => context.push('/admin/invite'),
          icon: const Icon(Icons.qr_code_2),
        ),
        const LeaveEventAction(),
      ],
      child: SessionGuard(
        builder: (context, session) {
          if (!session.participant.canAccessAdmin) {
            return Center(
              child: Text(l10n.adminOnlyAdmins),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdminEventCard(session: session),
              const SizedBox(height: 12),
              AdminPilotReadinessCard(session: session),
              const SizedBox(height: 12),
              AdminChannelsCard(session: session),
              const SizedBox(height: 12),
              AdminParticipantsCard(session: session),
              const SizedBox(height: 12),
              AdminLogsCard(eventId: session.event.id),
            ],
          );
        },
      ),
    );
  }
}
