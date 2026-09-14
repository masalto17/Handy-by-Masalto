import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_helpers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_template.dart';
import 'package:event_radio_app/src/shared/presentation/error_localizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Tarjeta con la informacion general del evento y acciones de estado.
class AdminEventCard extends ConsumerWidget {
  const AdminEventCard({required this.session, super.key});

  final EventSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = session.event.endsAt.difference(session.event.startsAt);

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
                    AppLocalizations.of(context).adminEventCard,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).adminCreateEvent,
                  onPressed: () => _showEventDialog(
                    context,
                    ref,
                    session: session,
                    createNew: true,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).adminEditEvent,
                  onPressed: () => _showEventDialog(
                    context,
                    ref,
                    session: session,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              session.event.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              session.event.description ??
                  AppLocalizations.of(context).adminNoDescription,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaStatus,
                  value: session.event.status.value,
                ),
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaStart,
                  value:
                      DateFormat('dd/MM HH:mm').format(session.event.startsAt),
                ),
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaEnd,
                  value: DateFormat('dd/MM HH:mm').format(session.event.endsAt),
                ),
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaDuration,
                  value:
                      '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                ),
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaChannels,
                  value: session.channels.length.toString(),
                ),
                _MetaChip(
                  label: AppLocalizations.of(context).adminMetaParticipants,
                  value: session.participants.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _extendEvent(context, ref),
                  icon: const Icon(Icons.more_time),
                  label: Text(AppLocalizations.of(context).adminExtend8h),
                ),
                if (session.event.status != EventStatus.closed)
                  OutlinedButton.icon(
                    onPressed: () => _closeEventNow(context, ref),
                    icon: const Icon(Icons.lock_clock),
                    label: Text(AppLocalizations.of(context).adminCloseNow),
                  ),
                if (!session.event.isOperational(DateTime.now()))
                  ElevatedButton.icon(
                    onPressed: () => _reactivateEvent(context, ref),
                    icon: const Icon(Icons.play_circle_outline),
                    label:
                        Text(AppLocalizations.of(context).adminReactivate8h),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEventDialog(
    BuildContext context,
    WidgetRef ref, {
    required EventSession session,
    bool createNew = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: createNew ? l10n.adminNewOperative : session.event.name,
    );
    final descriptionController = TextEditingController(
      text: createNew
          ? l10n.createEventDefaultDescription
          : session.event.description ?? '',
    );
    var startsAt = createNew ? DateTime.now() : session.event.startsAt;
    final initialDuration = createNew
        ? const Duration(hours: 3)
        : session.event.endsAt.difference(session.event.startsAt);
    final durationHoursController = TextEditingController(
      text: initialDuration.inHours.toString(),
    );
    final durationMinutesController = TextEditingController(
      text: initialDuration.inMinutes.remainder(60).toString(),
    );
    var status = session.event.status;
    var selectedTemplate = EventTemplate.all.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(createNew ? l10n.adminCreateEvent : l10n.adminEditEvent),
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
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                          labelText: l10n.adminDialogDescription),
                    ),
                    const SizedBox(height: 12),
                    if (createNew) ...[
                      _EventTemplatePicker(
                        selected: selectedTemplate,
                        onChanged: (template) =>
                            setState(() => selectedTemplate = template),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _SchedulePickerRow(
                      startsAt: startsAt,
                      onPickDate: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: startsAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked == null) return;
                        setState(() {
                          startsAt = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            startsAt.hour,
                            startsAt.minute,
                          );
                        });
                      },
                      onPickTime: () async {
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(startsAt),
                        );
                        if (picked == null) return;
                        setState(() {
                          startsAt = DateTime(
                            startsAt.year,
                            startsAt.month,
                            startsAt.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationHoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: l10n.adminDialogHours),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: l10n.adminDialogMinutes),
                          ),
                        ),
                      ],
                    ),
                    if (!createNew) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<EventStatus>(
                        initialValue: status,
                        decoration:
                            InputDecoration(labelText: l10n.adminDialogStatus),
                        items: EventStatus.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => status = value);
                        },
                      ),
                    ],
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
                    final eventName = nameController.text.trim();
                    if (eventName.isEmpty) {
                      showAdminError(dialogContext, l10n.adminErrorEventName);
                      return;
                    }
                    final duration = _durationFromControllers(
                      durationHoursController,
                      durationMinutesController,
                    );
                    if (duration == null) {
                      showAdminError(dialogContext, l10n.adminErrorDuration);
                      return;
                    }
                    final endsAt = startsAt.add(duration);
                    try {
                      final controller =
                          ref.read(currentSessionProvider.notifier);
                      var templateFailures = <String>[];
                      if (createNew) {
                        templateFailures =
                            await controller.createEventFromTemplate(
                          session: session,
                          name: eventName,
                          description: descriptionController.text.trim(),
                          startsAt: startsAt,
                          endsAt: endsAt,
                          template: selectedTemplate,
                        );
                      } else {
                        await controller.updateEventDetails(
                          session: session,
                          name: eventName,
                          description: descriptionController.text.trim(),
                          status: status,
                          startsAt: startsAt,
                          endsAt: endsAt,
                        );
                      }
                      ref.invalidate(eventLogsProvider(session.event.id));
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (context.mounted) {
                        final createdMessage = templateFailures.isEmpty
                            ? l10n.adminEventCreated
                            : l10n.adminEventCreatedWithFailures(
                                templateFailures.join(', '));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              createNew
                                  ? createdMessage
                                  : l10n.adminEventUpdated,
                            ),
                          ),
                        );
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
      descriptionController.dispose();
      durationHoursController.dispose();
      durationMinutesController.dispose();
    });
  }

  Duration? _durationFromControllers(
    TextEditingController hoursController,
    TextEditingController minutesController,
  ) {
    final hoursText = hoursController.text.trim();
    final minutesText = minutesController.text.trim();
    final hours = int.tryParse(hoursText);
    final minutes = int.tryParse(minutesText);
    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        minutes < 0 ||
        minutes > 59) {
      return null;
    }

    final totalMinutes = hours * 60 + minutes;
    if (totalMinutes < 15 || totalMinutes > 24 * 60) return null;
    return Duration(minutes: totalMinutes);
  }

  Future<void> _closeEventNow(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    try {
      await ref.read(currentSessionProvider.notifier).updateEventDetails(
            session: session,
            name: session.event.name,
            description: session.event.description ?? '',
            status: EventStatus.closed,
            startsAt: session.event.startsAt,
            endsAt: now,
          );
      ref.invalidate(eventLogsProvider(session.event.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminEventClosed)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorLocalizer.localize(l10n, error, l10n.adminOperationError),
          ),
        ),
      );
    }
  }

  Future<void> _reactivateEvent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    try {
      await ref.read(currentSessionProvider.notifier).updateEventDetails(
            session: session,
            name: session.event.name,
            description: session.event.description ?? '',
            status: EventStatus.active,
            startsAt: now.subtract(const Duration(minutes: 5)),
            endsAt: now.add(const Duration(hours: 8)),
          );
      ref.invalidate(eventLogsProvider(session.event.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).adminEventReactivated)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorLocalizer.localize(l10n, error, l10n.adminOperationError),
          ),
        ),
      );
    }
  }

  Future<void> _extendEvent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final startsAt = session.event.startsAt.isAfter(now)
        ? session.event.startsAt
        : now.subtract(const Duration(minutes: 5));
    try {
      await ref.read(currentSessionProvider.notifier).updateEventDetails(
            session: session,
            name: session.event.name,
            description: session.event.description ?? '',
            status: EventStatus.active,
            startsAt: startsAt,
            endsAt: now.add(const Duration(hours: 8)),
          );
      ref.invalidate(eventLogsProvider(session.event.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).adminEventExtended)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorLocalizer.localize(l10n, error, l10n.adminOperationError),
          ),
        ),
      );
    }
  }
}

class _SchedulePickerRow extends StatelessWidget {
  const _SchedulePickerRow({
    required this.startsAt,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime startsAt;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(DateFormat('dd/MM/yyyy').format(startsAt)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickTime,
            icon: const Icon(Icons.schedule),
            label: Text(DateFormat('HH:mm').format(startsAt)),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EventTemplatePicker extends StatelessWidget {
  const _EventTemplatePicker({
    required this.selected,
    required this.onChanged,
  });

  final EventTemplate selected;
  final ValueChanged<EventTemplate> onChanged;

  static const Map<String, IconData> _icons = {
    'tune': Icons.tune,
    'festival': Icons.festival,
    'music_note': Icons.music_note,
    'business_center': Icons.business_center,
    'directions_run': Icons.directions_run,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).adminTemplate,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: EventTemplate.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final template = EventTemplate.all[index];
              final isSelected = template.id == selected.id;
              final l10n = AppLocalizations.of(context);
              return Semantics(
                selected: isSelected,
                label: isSelected
                    ? l10n.a11yTemplateSelected(template.name)
                    : l10n.a11yTemplateUnselected(template.name),
                child: InkWell(
                  onTap: () => onChanged(template),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.brandGold
                            : AppTheme.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? AppTheme.brandGold.withValues(alpha: 0.10)
                          : AppTheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _icons[template.icon] ?? Icons.tune,
                          color:
                              isSelected ? AppTheme.brandGold : AppTheme.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Text(
                            template.tagline,
                            style: const TextStyle(
                              color: AppTheme.textSubtle,
                              fontSize: 10.5,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
