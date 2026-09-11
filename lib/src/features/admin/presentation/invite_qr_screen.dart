import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteQrScreen extends StatelessWidget {
  const InviteQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.invitationsTitle,
      actions: const [LeaveEventAction()],
      child: SessionGuard(
        builder: (context, session) {
          final participants = session.participant.canAccessAdmin
              ? session.participants
              : [session.participant];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.invitationsEventTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                session.event.name,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                '${DateFormat('dd/MM HH:mm').format(session.event.startsAt)} - ${DateFormat('HH:mm').format(session.event.endsAt)}',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              if (session.participant.canAccessAdmin)
                ElevatedButton.icon(
                  onPressed: () => _copyAllInvitations(context, session),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l10n.invitationsCopyAll),
                ),
              if (session.participant.canAccessAdmin)
                const SizedBox(height: 12),
              const _InviteUsageNote(),
              const SizedBox(height: 12),
              ...participants.map(
                (participant) => _ParticipantInviteCard(
                  session: session,
                  participant: participant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteUsageNote extends StatelessWidget {
  const _InviteUsageNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context).invitationsUsageNote,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _ParticipantInviteCard extends StatelessWidget {
  const _ParticipantInviteCard({
    required this.session,
    required this.participant,
  });

  final EventSession session;
  final EventParticipant participant;

  @override
  Widget build(BuildContext context) {
    final qrValue = _inviteUri(participant.inviteCode);
    final channels = _assignedChannels(context, session, participant);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: participant.canAccessAdmin
                      ? AppTheme.accent
                      : AppTheme.surfaceRaised,
                  child: Icon(
                    participant.canAccessAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.badge_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${participant.role.value} · ${channels.isEmpty ? AppLocalizations.of(context).invitationsNoChannels : channels}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: qrValue,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).invitationsEntryCode,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            SelectableText(
              participant.inviteCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              qrValue,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyText(
                    context,
                    participant.inviteCode,
                    AppLocalizations.of(context).invitationsCodeCopied,
                  ),
                  icon: const Icon(Icons.pin_outlined),
                  label: Text(AppLocalizations.of(context).invitationsCopyCode),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyText(
                    context,
                    qrValue,
                    AppLocalizations.of(context).invitationsInviteCopied,
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(AppLocalizations.of(context).invitationsCopyInvite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _copyAllInvitations(
  BuildContext context,
  EventSession session,
) async {
  final l10n = AppLocalizations.of(context);
  final buffer = StringBuffer()
    ..writeln('Handy - ${l10n.invitationsTitle.toLowerCase()}')
    ..writeln('${l10n.createEventName}: ${session.event.name}')
    ..writeln(
      '${DateFormat('dd/MM HH:mm').format(session.event.startsAt)} - ${DateFormat('HH:mm').format(session.event.endsAt)}',
    )
    ..writeln('')
    ..writeln(l10n.invitationsInstructions1)
    ..writeln(l10n.invitationsInstructions2)
    ..writeln(l10n.invitationsInstructions3)
    ..writeln('');

  for (final participant in session.participants) {
    buffer
      ..writeln('- ${participant.displayName}')
      ..writeln('  ${participant.role.value}')
      ..writeln('  ${participant.inviteCode}')
      ..writeln('  ${_inviteUri(participant.inviteCode)}')
      ..writeln('  ${_assignedChannels(context, session, participant)}')
      ..writeln('');
  }

  await _copyText(context, buffer.toString(), l10n.invitationsCopiedAll);
}

Future<void> _copyText(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _assignedChannels(BuildContext context, EventSession session, EventParticipant participant) {
  final channels = session.orderedChannels
      .where(
        (channel) =>
            session
                .permissionForParticipant(
                  participantId: participant.id,
                  channelId: channel.id,
                )
                ?.canListen ??
            false,
      )
      .map((channel) => channel.name)
      .join(', ');
  return channels.isEmpty ? AppLocalizations.of(context).invitationsNotAssigned : channels;
}

String _inviteUri(String inviteCode) => 'event-radio://join?code=$inviteCode';
