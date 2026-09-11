import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/features/admin/presentation/admin_helpers.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Tarjeta de checklist de puesta en marcha (pilot readiness).
class AdminPilotReadinessCard extends ConsumerWidget {
  const AdminPilotReadinessCard({required this.session, super.key});

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
                  label: Text(canOperate
                      ? AppLocalizations.of(context).adminExtend8h
                      : AppLocalizations.of(context).adminActivate8h),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/invite'),
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(
                      AppLocalizations.of(context).adminViewInvitations),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _copyReadinessSummary(context, checks, ready),
                  icon: const Icon(Icons.copy),
                  label: Text(
                      AppLocalizations.of(context).adminCopyTestPackage),
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

    // Los strings de diagnostico del pilot check quedan intencionalmente en
    // español: son un instrumento interno del organizador, no UI de usuario.
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
        detail:
            'Verificar http://127.0.0.1:8787/transcribe antes del ensayo',
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
        ..writeln('  ${inviteUri(participant.inviteCode)}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).adminTestPackageCopied)),
    );
  }

  Future<void> _extendEventForPilot(
      BuildContext context, WidgetRef ref) async {
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
      SnackBar(
          content: Text(AppLocalizations.of(context).adminEventReady8h)),
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
            const Icon(Icons.warning_amber_outlined,
                color: Colors.orangeAccent),
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
      label: Text(ready
          ? AppLocalizations.of(context).adminReadyTest
          : AppLocalizations.of(context).adminReview),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      visualDensity: VisualDensity.compact,
    );
  }
}
