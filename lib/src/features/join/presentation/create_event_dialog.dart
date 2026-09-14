import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:event_radio_app/src/shared/domain/event_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bootstrap: crea un evento nuevo sin necesidad de un codigo de invitacion
/// previo. Pensado para un organizador que abre la app por primera vez (o
/// para alguien que ya uso un codigo antes y ahora quiere armar su propio
/// evento). Internamente usa la misma sesion anonima que el ingreso por
/// codigo -- no depende de "Continuar con Gmail".
///
/// Devuelve `true` si el evento se creo y ya quedo activo en la sesion.
Future<bool?> showCreateEventDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _CreateEventDialog(),
  );
}

class _CreateEventDialog extends ConsumerStatefulWidget {
  const _CreateEventDialog();

  @override
  ConsumerState<_CreateEventDialog> createState() =>
      _CreateEventDialogState();
}

class _CreateEventDialogState extends ConsumerState<_CreateEventDialog> {
  final _organizerController = TextEditingController();
  final _eventNameController = TextEditingController(text: 'Mi evento');
  final _durationHoursController = TextEditingController(text: '8');
  EventTemplate _template = EventTemplate.all.first;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _organizerController.dispose();
    _eventNameController.dispose();
    _durationHoursController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final organizerName = _organizerController.text.trim();
    final eventName = _eventNameController.text.trim();
    final hours = int.tryParse(_durationHoursController.text.trim());

    final l10n = AppLocalizations.of(context);
    if (organizerName.isEmpty) {
      setState(() => _error = l10n.createEventErrorName);
      return;
    }
    if (eventName.isEmpty) {
      setState(() => _error = l10n.createEventErrorEventName);
      return;
    }
    if (hours == null || hours < 1 || hours > 24) {
      setState(() => _error = l10n.createEventErrorDuration);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final startsAt = DateTime.now();
    final endsAt = startsAt.add(Duration(hours: hours));
    // Sesion placeholder: create_event_with_admin solo necesita el nombre y
    // telefono del organizador, no una sesion real preexistente.
    final placeholder = EventSession(
      event: EventRadioEvent(
        id: '',
        name: '',
        startsAt: startsAt,
        endsAt: endsAt,
        status: EventStatus.draft,
      ),
      participant: EventParticipant(
        id: '',
        eventId: '',
        displayName: organizerName,
        role: ParticipantRole.coordinator,
        inviteCode: '',
        inviteStatus: 'pending',
      ),
      channels: const [],
      permissions: const [],
    );

    try {
      await ref.read(currentSessionProvider.notifier).createEventFromTemplate(
            session: placeholder,
            name: eventName,
            description: l10n.createEventDefaultDescription,
            startsAt: startsAt,
            endsAt: endsAt,
            template: _template,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = l10n.createEventError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.createEventTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createEventDescription,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _organizerController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.createEventYourName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventNameController,
              decoration:
                  InputDecoration(labelText: l10n.createEventName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationHoursController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.createEventDuration),
            ),
            const SizedBox(height: 16),
            Text(l10n.createEventTemplate, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EventTemplate.all.map((template) {
                final isSelected = template.id == _template.id;
                return ChoiceChip(
                  label: Text(template.name),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _template = template),
                  selectedColor: AppTheme.brandGold.withValues(alpha: 0.22),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              _template.tagline,
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.createEventCancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createEventCreate),
        ),
      ],
    );
  }
}
