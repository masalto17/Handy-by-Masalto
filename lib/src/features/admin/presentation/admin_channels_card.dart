import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_helpers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/presentation/error_localizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tarjeta con la lista de canales y acciones de CRUD.
class AdminChannelsCard extends ConsumerWidget {
  const AdminChannelsCard({required this.session, super.key});

  final EventSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    AppLocalizations.of(context).adminChannelsCard,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).adminCreateChannel,
                  onPressed: () => _showChannelDialog(context, ref, session),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            ...session.orderedChannels.map(
              (channel) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  channel.isEmergency ? Icons.priority_high : Icons.radio,
                ),
                title: Text(channel.name),
                subtitle: Text(
                  AppLocalizations.of(context).adminChannelSummary(
                      channel.code, channel.priority),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: AppLocalizations.of(context).adminEditChannel,
                      onPressed: () => _showChannelDialog(
                        context,
                        ref,
                        session,
                        channel: channel,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).adminDeleteChannel,
                      onPressed: session.channels.length <= 1
                          ? null
                          : () => _confirmDeleteChannel(
                                context,
                                ref,
                                session,
                                channel,
                              ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChannelDialog(
    BuildContext context,
    WidgetRef ref,
    EventSession session, {
    EventChannel? channel,
  }) async {
    final nameController = TextEditingController(text: channel?.name ?? '');
    final codeController = TextEditingController(text: channel?.code ?? '');
    final descriptionController =
        TextEditingController(text: channel?.description ?? '');
    final priorityController =
        TextEditingController(text: '${channel?.priority ?? 50}');
    var isEmergency = channel?.isEmergency ?? false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(channel == null
                  ? l10n.adminCreateChannel
                  : l10n.adminEditChannel),
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
                      controller: codeController,
                      decoration:
                          InputDecoration(labelText: l10n.adminChannelCode),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                          labelText: l10n.adminDialogDescription),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priorityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: l10n.adminChannelPriority),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.adminChannelCritical),
                      value: isEmergency,
                      onChanged: (value) =>
                          setState(() => isEmergency = value),
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
                    final channelName = nameController.text.trim();
                    final channelCode = normalizeChannelCode(
                      codeController.text,
                    );
                    final priority = int.tryParse(
                      priorityController.text.trim(),
                    );
                    if (channelName.isEmpty) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelName,
                      );
                      return;
                    }
                    if (channelCode.isEmpty) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelCode,
                      );
                      return;
                    }
                    final codeAlreadyExists = session.channels.any(
                      (item) =>
                          item.id != channel?.id && item.code == channelCode,
                    );
                    if (codeAlreadyExists) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelCodeDuplicate,
                      );
                      return;
                    }
                    if (priority == null || priority < 0 || priority > 100) {
                      showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelPriority,
                      );
                      return;
                    }
                    try {
                      final controller =
                          ref.read(currentSessionProvider.notifier);
                      if (channel == null) {
                        await controller.createChannel(
                          session: session,
                          name: channelName,
                          code: channelCode,
                          description: descriptionController.text.trim(),
                          priority: priority,
                          isEmergency: isEmergency,
                        );
                      } else {
                        await controller.updateChannel(
                          session: session,
                          channel: channel,
                          name: channelName,
                          code: channelCode,
                          description: descriptionController.text.trim(),
                          priority: priority,
                          isEmergency: isEmergency,
                        );
                      }
                      ref.invalidate(eventLogsProvider(session.event.id));
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      showAdminError(
                        dialogContext,
                        ErrorLocalizer.localize(
                          AppLocalizations.of(dialogContext),
                          error,
                          AppLocalizations.of(dialogContext)
                              .adminOperationError,
                        ),
                      );
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
      codeController.dispose();
      descriptionController.dispose();
      priorityController.dispose();
    });
  }

  Future<void> _confirmDeleteChannel(
    BuildContext context,
    WidgetRef ref,
    EventSession session,
    EventChannel channel,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.adminDeleteChannel),
          content: Text(
            l10n.adminDeleteChannelContent(channel.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.adminDialogCancel),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.adminDialogDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      await ref.read(currentSessionProvider.notifier).deleteChannel(
            session: session,
            channel: channel,
          );
      ref.invalidate(eventLogsProvider(session.event.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminChannelDeleted(channel.name))),
      );
    } catch (error) {
      if (!context.mounted) return;
      showAdminError(
        context,
        ErrorLocalizer.localize(l10n, error, l10n.adminOperationError),
      );
    }
  }
}
