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
    return AppScaffold(
      title: 'Invitaciones',
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
                'Invitaciones del evento',
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
                  label: const Text('Copiar todas las invitaciones'),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Para probar con otra persona: compartile su codigo o QR. Cada participante debe entrar con su propio codigo para ver solo sus canales.',
          style: TextStyle(color: Colors.white70),
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
    final channels = _assignedChannels(session, participant);

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
                        '${participant.role.value} · ${channels.isEmpty ? 'sin canales' : channels}',
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
            const Text(
              'Codigo de ingreso',
              style: TextStyle(fontWeight: FontWeight.w800),
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
                    'Codigo copiado.',
                  ),
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Copiar codigo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyText(
                    context,
                    qrValue,
                    'Invitacion copiada.',
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar invitacion'),
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
  final buffer = StringBuffer()
    ..writeln('Handy - invitaciones')
    ..writeln('Evento: ${session.event.name}')
    ..writeln(
      'Horario: ${DateFormat('dd/MM HH:mm').format(session.event.startsAt)} - ${DateFormat('HH:mm').format(session.event.endsAt)}',
    )
    ..writeln('')
    ..writeln('Instrucciones:')
    ..writeln('1. Abrir Handy.')
    ..writeln('2. Ingresar el codigo asignado.')
    ..writeln('3. Entrar al canal correspondiente.')
    ..writeln('')
    ..writeln('Participantes:');

  for (final participant in session.participants) {
    buffer
      ..writeln('- ${participant.displayName}')
      ..writeln('  Rol: ${participant.role.value}')
      ..writeln('  Codigo: ${participant.inviteCode}')
      ..writeln('  Link/QR: ${_inviteUri(participant.inviteCode)}')
      ..writeln('  Canales: ${_assignedChannels(session, participant)}')
      ..writeln('');
  }

  await _copyText(context, buffer.toString(), 'Invitaciones copiadas.');
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

String _assignedChannels(EventSession session, EventParticipant participant) {
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
  return channels.isEmpty ? 'sin asignar' : channels;
}

String _inviteUri(String inviteCode) => 'event-radio://join?code=$inviteCode';
