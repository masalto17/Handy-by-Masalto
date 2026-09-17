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
  /// Duraciones ofrecidas como atajo. Cubren la mayoria de los eventos reales
  /// y evitan que el organizador tenga que pensar un numero desde cero.
  static const _durationPresets = [4, 6, 8, 12];

  final _organizerController = TextEditingController();
  final _eventNameController = TextEditingController(text: 'Mi evento');
  final _durationHoursController = TextEditingController(text: '8');

  /// Plantilla por defecto: la primera con canales reales, no el evento en
  /// blanco. Un organizador sin experiencia arranca con algo operativo.
  EventTemplate _template = EventTemplate.all.firstWhere(
    (template) => template.additionalChannels.isNotEmpty,
    orElse: () => EventTemplate.all.first,
  );

  /// Duracion elegida por chip, o `null` si el organizador escribio una propia.
  int? _presetHours = 8;
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
    final hours =
        _presetHours ?? int.tryParse(_durationHoursController.text.trim());

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
            const SizedBox(height: 16),
            Text(
              l10n.createEventDuration,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hours in _durationPresets)
                  ChoiceChip(
                    label: Text(l10n.createEventDurationPreset(hours)),
                    selected: _presetHours == hours,
                    onSelected: (_) => setState(() => _presetHours = hours),
                    selectedColor: AppTheme.brandGold.withValues(alpha: 0.22),
                  ),
                ChoiceChip(
                  label: Text(l10n.createEventDurationOther),
                  selected: _presetHours == null,
                  onSelected: (_) => setState(() => _presetHours = null),
                  selectedColor: AppTheme.brandGold.withValues(alpha: 0.22),
                ),
              ],
            ),
            if (_presetHours == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _durationHoursController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.createEventDurationCustomLabel,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.createEventTemplate,
              style: Theme.of(context).textTheme.labelLarge,
            ),
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
            const SizedBox(height: 14),
            // Preview: el organizador ve exactamente con que canales arranca
            // antes de crear, en vez de descubrirlo despues en el panel admin.
            _ChannelsPreview(template: _template),
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

/// Lista los canales con los que quedara el evento segun la plantilla elegida.
///
/// El backend siempre crea "Produccion", asi que se muestra primero y luego
/// los adicionales que aporta la plantilla.
class _ChannelsPreview extends StatelessWidget {
  const _ChannelsPreview({required this.template});

  final EventTemplate template;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final additional = template.additionalChannels;

    return DecoratedBox(
      decoration: AppTheme.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createEventChannelsPreview,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ChannelChip(label: l10n.createEventProductionChannel),
                for (final channel in additional)
                  _ChannelChip(
                    label: channel.name,
                    isEmergency: channel.isEmergency,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.label, this.isEmergency = false});

  final String label;
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    final color = isEmergency ? AppTheme.danger : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEmergency) ...[
            const Icon(Icons.priority_high, size: 12, color: AppTheme.danger),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
