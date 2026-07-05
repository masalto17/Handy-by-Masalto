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

    if (organizerName.isEmpty) {
      setState(() => _error = 'Ingresa tu nombre.');
      return;
    }
    if (eventName.isEmpty) {
      setState(() => _error = 'Ingresa un nombre para el evento.');
      return;
    }
    if (hours == null || hours < 1 || hours > 24) {
      setState(() => _error = 'La duracion debe estar entre 1 y 24 horas.');
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
            description: 'Evento creado desde Handy.',
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
        _error = 'No pudimos crear el evento. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear evento nuevo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sos el organizador: creas el evento y quedas como '
              'coordinador. Despues invitas a tu equipo por codigo o QR.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _organizerController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventNameController,
              decoration:
                  const InputDecoration(labelText: 'Nombre del evento'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationHoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duracion (horas)'),
            ),
            const SizedBox(height: 16),
            Text('Plantilla', style: Theme.of(context).textTheme.labelLarge),
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
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
