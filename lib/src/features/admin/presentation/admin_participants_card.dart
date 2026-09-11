import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_helpers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Tarjeta con la lista de participantes y acciones de CRUD + invitaciones.
class AdminParticipantsCard extends ConsumerWidget {
  const AdminParticipantsCard({required this.session, super.key});

  final EventSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminParticipantsCard,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.adminCopyInvitations,
                  onPressed: () => _copyPilotInvitations(context, session),
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  tooltip: l10n.adminInviteParticipant,
                  onPressed: () =>
                      _showParticipantDialog(context, ref, session),
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
            ...session.participants.map(
              (participant) {
                final assignedChannels = session.allPermissions
                    .where(
                      (permission) =>
                          permission.participantId == participant.id &&
                          permission.canListen,
                    )
                    .length;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(participant.displayName),
                  subtitle: Text(
                    l10n.adminParticipantSummary(
                      participant.role.value,
                      participant.inviteCode,
                      assignedChannels,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip:
                            l10n.adminViewInviteOf(participant.displayName),
                        onPressed: () => _showParticipantInviteDialog(
                          context,
                          session,
                          participant,
                        ),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      IconButton(
                        tooltip:
                            l10n.adminEditChannelsOf(participant.displayName),
                        onPressed: () => _showParticipantChannelsDialog(
                          context,
                          ref,
                          session,
                          participant,
                        ),
                        icon: const Icon(Icons.settings_input_antenna),
                      ),
                      IconButton(
                        tooltip: l10n.adminEditParticipant,
                        onPressed: () => _showParticipantDialog(
                          context,
                          ref,
                          session,
                          participant: participant,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: l10n
                            .adminDeleteParticipantOf(participant.displayName),
                        onPressed: participant.id == session.participant.id
                            ? null
                            : () => _confirmDeleteParticipant(
                                  context,
                                  ref,
                                  session,
                                  participant,
                                ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showParticipantDialog(
    BuildContext context,
    WidgetRef ref,
    EventSession session, {
    EventParticipant? participant,
  }) async {
    final nameController =
        TextEditingController(text: participant?.displayName ?? '');
    final phoneController =
        TextEditingController(text: participant?.phone ?? '');
    final inviteController = TextEditingController(
      text: participant?.inviteCode ?? generateUniqueInviteCode(session),
    );
    var role = participant?.role ?? ParticipantRole.participant;

    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                participant == null
                    ? l10n.adminInviteParticipant
                    : l10n.adminEditParticipant,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration:
                          InputDecoration(labelText: l10n.adminDialogName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                          labelText: l10n.adminParticipantPhone),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: inviteController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.adminParticipantInviteCode,
                        helperText: participant == null
                            ? l10n.adminParticipantInviteHelperNew
                            : l10n.adminParticipantInviteHelperEdit,
                        suffixIcon: IconButton(
                          tooltip: l10n.adminGenerateSecureCode,
                          onPressed: () {
                            inviteController.text = generateUniqueInviteCode(
                              session,
                              exceptParticipantId: participant?.id,
                            );
                          },
                          icon: const Icon(Icons.auto_fix_high),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ParticipantRole>(
                      initialValue: role,
                      decoration: InputDecoration(
                          labelText: l10n.adminParticipantRole),
                      items: ParticipantRole.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => role = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.adminDialogCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final displayName = nameController.text.trim();
                    final inviteCode = normalizeInviteCode(
                      inviteController.text,
                    );
                    if (displayName.isEmpty) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorParticipantName,
                      );
                      return;
                    }
                    if (inviteCode.isEmpty) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorParticipantCode,
                      );
                      return;
                    }
                    final inviteAlreadyExists = session.participants.any(
                      (item) =>
                          item.id != participant?.id &&
                          item.inviteCode == inviteCode,
                    );
                    if (inviteAlreadyExists) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorParticipantCodeDuplicate,
                      );
                      return;
                    }
                    final controller =
                        ref.read(currentSessionProvider.notifier);
                    if (participant == null) {
                      await controller.createParticipant(
                        session: session,
                        displayName: displayName,
                        phone: phoneController.text.trim(),
                        role: role,
                        inviteCode: inviteCode,
                      );
                    } else {
                      await controller.updateParticipant(
                        session: session,
                        participant: participant,
                        displayName: displayName,
                        phone: phoneController.text.trim(),
                        role: role,
                        inviteCode: inviteCode,
                      );
                    }
                    ref.invalidate(eventLogsProvider(session.event.id));
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.adminDialogSave),
                ),
              ],
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      nameController.dispose();
      phoneController.dispose();
      inviteController.dispose();
    });
  }

  Future<void> _copyPilotInvitations(
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
      ..writeln('Participantes:');

    for (final participant in session.participants) {
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

      buffer
        ..writeln('- ${participant.displayName}')
        ..writeln('  Rol: ${participant.role.value}')
        ..writeln('  Codigo: ${participant.inviteCode}')
        ..writeln('  Link/QR: ${inviteUri(participant.inviteCode)}')
        ..writeln(
            '  Canales: ${channels.isEmpty ? 'sin asignar' : channels}')
        ..writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context).adminInvitationsCopied)),
    );
  }

  Future<void> _showParticipantInviteDialog(
    BuildContext context,
    EventSession session,
    EventParticipant participant,
  ) async {
    final qrValue = inviteUri(participant.inviteCode);

    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.adminInvitationOf(participant.displayName)),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.event.name,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox.square(
                        dimension: 220,
                        child: QrImageView(
                          data: qrValue,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.invitationsEntryCode,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    participant.inviteCode,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    qrValue,
                    style: const TextStyle(color: AppTheme.textSubtle),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.adminDialogClose),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: participant.inviteCode),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.invitationsCodeCopied)),
                );
              },
              icon: const Icon(Icons.pin_outlined),
              label: Text(l10n.invitationsCopyCode),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: qrValue));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.invitationsInviteCopied)),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.invitationsCopyInvite),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteParticipant(
    BuildContext context,
    WidgetRef ref,
    EventSession session,
    EventParticipant participant,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.adminDeleteParticipant),
          content: Text(
            l10n.adminDeleteParticipantContent(
              participant.displayName,
              participant.inviteCode,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.adminDialogCancel),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.person_remove_outlined),
              label: Text(l10n.adminDialogDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await ref.read(currentSessionProvider.notifier).deleteParticipant(
          session: session,
          participant: participant,
        );
    ref.invalidate(eventLogsProvider(session.event.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.adminParticipantDeleted(participant.displayName)),
      ),
    );
  }

  Future<void> _showParticipantChannelsDialog(
    BuildContext context,
    WidgetRef ref,
    EventSession session,
    EventParticipant participant,
  ) async {
    final drafts = {
      for (final channel in session.orderedChannels)
        channel.id: _ChannelPermissionDraft.fromPermission(
          session.permissionForParticipant(
            participantId: participant.id,
            channelId: channel.id,
          ),
        ),
    };

    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.adminChannelsOf(participant.displayName)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final channel in session.orderedChannels)
                        _ChannelPermissionTile(
                          channel: channel,
                          draft: drafts[channel.id]!,
                          talkDisabled:
                              participant.role == ParticipantRole.viewer,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.adminDialogCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final permissions = drafts.entries
                        .where((entry) => entry.value.canListen)
                        .map(
                          (entry) => ChannelPermission(
                            channelId: entry.key,
                            participantId: participant.id,
                            canTalk: entry.value.canTalk,
                          ),
                        )
                        .toList();
                    await ref
                        .read(currentSessionProvider.notifier)
                        .updateParticipantChannels(
                          session: session,
                          participant: participant,
                          permissions: permissions,
                        );
                    ref.invalidate(eventLogsProvider(session.event.id));
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.adminDialogSave),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChannelPermissionDraft {
  _ChannelPermissionDraft({
    required this.canListen,
    required this.canTalk,
  });

  factory _ChannelPermissionDraft.fromPermission(
      ChannelPermission? permission) {
    return _ChannelPermissionDraft(
      canListen: permission?.canListen ?? false,
      canTalk: permission?.canTalk ?? false,
    );
  }

  bool canListen;
  bool canTalk;
}

class _ChannelPermissionTile extends StatelessWidget {
  const _ChannelPermissionTile({
    required this.channel,
    required this.draft,
    required this.talkDisabled,
    required this.onChanged,
  });

  final EventChannel channel;
  final _ChannelPermissionDraft draft;
  final bool talkDisabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(channel.name),
      subtitle: Text(
        draft.canListen
            ? draft.canTalk
                ? l10n.adminPermListenAndTalk
                : l10n.adminPermListenOnly
            : l10n.adminPermNoAccess,
      ),
      leading: Checkbox(
        value: draft.canListen,
        onChanged: (value) {
          draft.canListen = value ?? false;
          if (!draft.canListen) draft.canTalk = false;
          onChanged();
        },
      ),
      trailing: Switch(
        value: draft.canListen && draft.canTalk,
        onChanged: draft.canListen && !talkDisabled
            ? (value) {
                draft.canTalk = value;
                onChanged();
              }
            : null,
      ),
    );
  }
}
