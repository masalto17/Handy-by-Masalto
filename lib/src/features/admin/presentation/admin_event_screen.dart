import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_template.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_generator.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:event_radio_app/src/shared/presentation/session_actions.dart';
import 'package:event_radio_app/src/shared/presentation/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
              child:
                  Text(l10n.adminOnlyAdmins),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EventAdminCard(session: session),
              const SizedBox(height: 12),
              _PilotReadinessCard(session: session),
              const SizedBox(height: 12),
              _ChannelsAdminCard(session: session),
              const SizedBox(height: 12),
              _ParticipantsAdminCard(session: session),
              const SizedBox(height: 12),
              _LogsAdminCard(eventId: session.event.id),
            ],
          );
        },
      ),
    );
  }
}

class _PilotReadinessCard extends ConsumerWidget {
  const _PilotReadinessCard({required this.session});

  final EventSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = _buildChecks();
    final requiredChecks = checks.where((check) => check.required);
    final ready = requiredChecks.every((check) => check.isReady);
    final canOperate = session.event.isOperational(DateTime.now());

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
                    AppLocalizations.of(context).adminPilotReadiness,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _ReadinessPill(ready: ready),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).adminPilotReadinessHint,
              style: const TextStyle(color: Colors.white70),
            ),
            if (!canOperate) ...[
              const SizedBox(height: 12),
              const _PilotActionBanner(),
            ],
            const SizedBox(height: 12),
            ...checks.map(_PilotCheckTile.new),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _extendEventForPilot(context, ref),
                  icon: const Icon(Icons.more_time),
                  label: Text(canOperate ? AppLocalizations.of(context).adminExtend8h : AppLocalizations.of(context).adminActivate8h),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/invite'),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(AppLocalizations.of(context).adminViewInvitations),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _copyReadinessSummary(context, checks, ready),
                  icon: const Icon(Icons.copy),
                  label: Text(AppLocalizations.of(context).adminCopyTestPackage),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_PilotCheck> _buildChecks() {
    final duration = session.event.endsAt.difference(session.event.startsAt);
    final participantsWithAccess = <String>{
      for (final permission in session.allPermissions)
        if (permission.canListen) permission.participantId,
    };
    final participantsWithoutChannels = session.participants
        .where(
            (participant) => !participantsWithAccess.contains(participant.id))
        .map((participant) => participant.displayName)
        .toList();
    final inviteCodes = session.participants
        .map((participant) => participant.inviteCode)
        .where((code) => code.trim().isNotEmpty)
        .toSet();

    return [
      _PilotCheck(
        title: 'Supabase conectado',
        detail: EnvConfig.isSupabaseAvailable
            ? 'Modo real activo'
            : 'La app esta en mock/local sin backend real',
        isReady: EnvConfig.isSupabaseAvailable,
        required: EnvConfig.hasSupabaseConfig,
      ),
      _PilotCheck(
        title: 'LiveKit conectado',
        detail: EnvConfig.hasLiveKitConfig
            ? 'PTT real habilitado'
            : 'Falta LIVEKIT_AUDIO_ENABLED=true y LIVEKIT_URL',
        isReady: EnvConfig.hasLiveKitConfig,
        required: EnvConfig.isSupabaseAvailable,
      ),
      const _PilotCheck(
        title: 'Whisper local',
        detail: 'Verificar http://127.0.0.1:8787/transcribe antes del ensayo',
        isReady: true,
        required: false,
      ),
      const _PilotCheck(
        title: 'Historial reproducible',
        detail: 'PTT guarda audio y permite playback por canal',
        isReady: true,
      ),
      _PilotCheck(
        title: 'URL compartible',
        detail: EnvConfig.isLocalSupabase
            ? '127.0.0.1 sirve solo en esta maquina; usar deploy/tunel para telefonos'
            : 'Backend listo para prueba fuera de localhost',
        isReady: !EnvConfig.isLocalSupabase,
        required: false,
      ),
      _PilotCheck(
        title: 'Evento operativo ahora',
        detail: session.event.isOperational(DateTime.now())
            ? 'Activo hasta ${DateFormat('HH:mm').format(session.event.endsAt)}'
            : 'No permite ingreso/PTT ahora',
        isReady: session.event.isOperational(DateTime.now()),
      ),
      _PilotCheck(
        title: 'Fecha y duracion validas',
        detail:
            '${DateFormat('dd/MM HH:mm').format(session.event.startsAt)} - ${DateFormat('HH:mm').format(session.event.endsAt)}',
        isReady: duration.inMinutes >= 15 && duration.inMinutes <= 24 * 60,
      ),
      _PilotCheck(
        title: 'Canales operativos',
        detail: '${session.channels.length} canales configurados',
        isReady: session.channels.length >= 2,
      ),
      _PilotCheck(
        title: 'Participantes cargados',
        detail: '${session.participants.length} participantes invitados',
        isReady: session.participants.length >= 2,
      ),
      _PilotCheck(
        title: 'Permisos por participante',
        detail: participantsWithoutChannels.isEmpty
            ? 'Todos tienen al menos un canal'
            : 'Sin canal: ${participantsWithoutChannels.join(', ')}',
        isReady: participantsWithoutChannels.isEmpty,
      ),
      _PilotCheck(
        title: 'Codigos de invitacion',
        detail: '${inviteCodes.length} codigos unicos',
        isReady: inviteCodes.length == session.participants.length,
      ),
      _PilotCheck(
        title: 'Canal critico/SOS',
        detail: session.channels.any((channel) => channel.isEmergency)
            ? 'Hay canal marcado como critico'
            : 'Falta marcar un canal critico',
        isReady: session.channels.any((channel) => channel.isEmergency),
      ),
    ];
  }

  Future<void> _copyReadinessSummary(
    BuildContext context,
    List<_PilotCheck> checks,
    bool ready,
  ) async {
    final buffer = StringBuffer()
      ..writeln('Handy - paquete de ensayo')
      ..writeln('Evento: ${session.event.name}')
      ..writeln(
          'Estado: ${ready ? 'LISTO PARA ENSAYO' : 'REVISAR ANTES DE ENSAYO'}')
      ..writeln(
          'Inicio: ${DateFormat('dd/MM/yyyy HH:mm').format(session.event.startsAt)}')
      ..writeln(
          'Fin: ${DateFormat('dd/MM/yyyy HH:mm').format(session.event.endsAt)}')
      ..writeln('Canales: ${session.channels.length}')
      ..writeln('Participantes: ${session.participants.length}')
      ..writeln('')
      ..writeln('Instrucciones para probar:')
      ..writeln('1. Cada persona entra con su codigo propio.')
      ..writeln('2. Validar que vea solo sus canales asignados.')
      ..writeln('3. Probar PTT real en un canal.')
      ..writeln('4. Probar broadcast desde un coordinador.')
      ..writeln('5. Reproducir audios desde historial.')
      ..writeln('6. Probar transcripcion automatica y boton manual.')
      ..writeln('7. Probar SOS y verificar historial.')
      ..writeln(
          'Nota: 127.0.0.1 no se comparte con otros telefonos; usar deploy o tunel.')
      ..writeln('');
    for (final check in checks) {
      buffer.writeln(
          '${check.isReady ? '[OK]' : '[ ]'} ${check.title}: ${check.detail}');
    }
    buffer
      ..writeln('')
      ..writeln('Invitaciones:');
    for (final participant in session.participants) {
      buffer
        ..writeln('- ${participant.displayName}: ${participant.inviteCode}')
        ..writeln('  ${_inviteUri(participant.inviteCode)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).adminTestPackageCopied)),
    );
  }

  Future<void> _extendEventForPilot(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final startsAt = session.event.startsAt.isAfter(now)
        ? session.event.startsAt
        : now.subtract(const Duration(minutes: 5));

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
      SnackBar(content: Text(AppLocalizations.of(context).adminEventReady8h)),
    );
  }
}

class _PilotActionBanner extends StatelessWidget {
  const _PilotActionBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2115),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).adminPilotActionBanner,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PilotCheck {
  const _PilotCheck({
    required this.title,
    required this.detail,
    required this.isReady,
    this.required = true,
  });

  final String title;
  final String detail;
  final bool isReady;
  final bool required;
}

class _PilotCheckTile extends StatelessWidget {
  const _PilotCheckTile(this.check);

  final _PilotCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.isReady
        ? Colors.greenAccent
        : check.required
            ? Colors.orangeAccent
            : Colors.white54;
    final icon = check.isReady
        ? Icons.check_circle_outline
        : check.required
            ? Icons.error_outline
            : Icons.info_outline;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(check.title),
      subtitle: Text(check.detail),
    );
  }
}

class _ReadinessPill extends StatelessWidget {
  const _ReadinessPill({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? Colors.greenAccent : Colors.orangeAccent;
    return Chip(
      avatar: Icon(
        ready ? Icons.verified_outlined : Icons.warning_amber_outlined,
        color: color,
        size: 16,
      ),
      label: Text(ready ? AppLocalizations.of(context).adminReadyTest : AppLocalizations.of(context).adminReview),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EventAdminCard extends ConsumerWidget {
  const _EventAdminCard({required this.session});

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
              session.event.description ?? AppLocalizations.of(context).adminNoDescription,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaChip(label: AppLocalizations.of(context).adminMetaStatus, value: session.event.status.value),
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
                    label: Text(AppLocalizations.of(context).adminReactivate8h),
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
              title: Text(createNew ? l10n.adminCreateEvent : l10n.adminEditEvent),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: l10n.adminDialogName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration:
                          InputDecoration(labelText: l10n.adminDialogDescription),
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
                            decoration:
                                InputDecoration(labelText: l10n.adminDialogHours),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationMinutesController,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(labelText: l10n.adminDialogMinutes),
                          ),
                        ),
                      ],
                    ),
                    if (!createNew) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<EventStatus>(
                        initialValue: status,
                        decoration: InputDecoration(labelText: l10n.adminDialogStatus),
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
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorEventName,
                      );
                      return;
                    }
                    final duration = _durationFromControllers(
                      durationHoursController,
                      durationMinutesController,
                    );
                    if (duration == null) {
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorDuration,
                      );
                      return;
                    }
                    final endsAt = startsAt.add(duration);
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
                          : l10n.adminEventCreatedWithFailures(templateFailures.join(', '));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            createNew ? createdMessage : l10n.adminEventUpdated,
                          ),
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
  }

  Future<void> _reactivateEvent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();

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
      SnackBar(content: Text(AppLocalizations.of(context).adminEventReactivated)),
    );
  }

  Future<void> _extendEvent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final startsAt = session.event.startsAt.isAfter(now)
        ? session.event.startsAt
        : now.subtract(const Duration(minutes: 5));

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
      SnackBar(content: Text(AppLocalizations.of(context).adminEventExtended)),
    );
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

class _ChannelsAdminCard extends ConsumerWidget {
  const _ChannelsAdminCard({required this.session});

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
                subtitle:
                    Text(AppLocalizations.of(context).adminChannelSummary(channel.code, channel.priority)),
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
              title: Text(channel == null ? l10n.adminCreateChannel : l10n.adminEditChannel),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: l10n.adminDialogName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(labelText: l10n.adminChannelCode),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          InputDecoration(labelText: l10n.adminDialogDescription),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priorityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: l10n.adminChannelPriority),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.adminChannelCritical),
                      value: isEmergency,
                      onChanged: (value) => setState(() => isEmergency = value),
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
                    final channelCode = _normalizeChannelCode(
                      codeController.text,
                    );
                    final priority = int.tryParse(
                      priorityController.text.trim(),
                    );
                    if (channelName.isEmpty) {
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelName,
                      );
                      return;
                    }
                    if (channelCode.isEmpty) {
                      _showAdminError(
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
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelCodeDuplicate,
                      );
                      return;
                    }
                    if (priority == null || priority < 0 || priority > 100) {
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorChannelPriority,
                      );
                      return;
                    }
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
    await ref.read(currentSessionProvider.notifier).deleteChannel(
          session: session,
          channel: channel,
        );
    ref.invalidate(eventLogsProvider(session.event.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.adminChannelDeleted(channel.name))),
    );
  }
}

class _ParticipantsAdminCard extends ConsumerWidget {
  const _ParticipantsAdminCard({required this.session});

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
                        tooltip: l10n.adminViewInviteOf(participant.displayName),
                        onPressed: () => _showParticipantInviteDialog(
                          context,
                          session,
                          participant,
                        ),
                        icon: const Icon(Icons.qr_code_2),
                      ),
                      IconButton(
                        tooltip: l10n.adminEditChannelsOf(participant.displayName),
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
                        tooltip:
                            l10n.adminDeleteParticipantOf(participant.displayName),
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
      text: participant?.inviteCode ?? _generateUniqueInviteCode(session),
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
                      decoration: InputDecoration(labelText: l10n.adminDialogName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(labelText: l10n.adminParticipantPhone),
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
                            inviteController.text = _generateUniqueInviteCode(
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
                      decoration: InputDecoration(labelText: l10n.adminParticipantRole),
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
                    final inviteCode = _normalizeInviteCode(
                      inviteController.text,
                    );
                    if (displayName.isEmpty) {
                      _showAdminError(
                        dialogContext,
                        l10n.adminErrorParticipantName,
                      );
                      return;
                    }
                    if (inviteCode.isEmpty) {
                      _showAdminError(
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
                      _showAdminError(
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
        ..writeln('  Link/QR: ${_inviteUri(participant.inviteCode)}')
        ..writeln('  Canales: ${channels.isEmpty ? 'sin asignar' : channels}')
        ..writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).adminInvitationsCopied)),
    );
  }

  Future<void> _showParticipantInviteDialog(
    BuildContext context,
    EventSession session,
    EventParticipant participant,
  ) async {
    final qrValue = _inviteUri(participant.inviteCode);

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
                    style: const TextStyle(color: Colors.white70),
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
                    style: const TextStyle(color: Colors.white60),
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

String _inviteUri(String inviteCode) => 'event-radio://join?code=$inviteCode';

String _normalizeChannelCode(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String _normalizeInviteCode(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
}

String _generateUniqueInviteCode(
  EventSession session, {
  String? exceptParticipantId,
}) {
  final existingCodes = session.participants
      .where((participant) => participant.id != exceptParticipantId)
      .map((participant) => participant.inviteCode)
      .toSet();
  return InviteCodeGenerator().generateUnique(existingCodes: existingCodes);
}

void _showAdminError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
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

class _LogsAdminCard extends ConsumerWidget {
  const _LogsAdminCard({required this.eventId});

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
            Text(l10n.adminLogsCard, style: Theme.of(context).textTheme.titleMedium),
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
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(l10n.adminLogsError),
            ),
          ],
        ),
      ),
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
              return InkWell(
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
                        color: isSelected ? AppTheme.brandGold : Colors.white70,
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
                            color: Colors.white60,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
