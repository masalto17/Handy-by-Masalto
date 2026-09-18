import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Boton de emergencia fijo, que se activa manteniendolo presionado.
///
/// Antes vivia dentro del scroll, debajo del PTT: pedir auxilio exigia
/// scrollear y encontrarlo. Ahora queda anclado al pie de la pantalla.
///
/// Como contrapartida de estar siempre bajo el pulgar, no se dispara con un
/// toque: hay que sostenerlo [holdDuration]. Es lo que hacen los equipos de
/// radio reales, y evita el SOS accidental sin costar el tiempo que costaria
/// un dialogo de confirmacion.
class SosHoldButton extends StatefulWidget {
  /// Crea el boton.
  const SosHoldButton({
    required this.enabled,
    required this.isSending,
    required this.onActivate,
    this.holdDuration = const Duration(milliseconds: 1200),
    super.key,
  });

  /// `false` si el operador no puede enviar SOS en este canal.
  final bool enabled;

  /// `true` mientras el SOS anterior se esta enviando.
  final bool isSending;

  /// Se invoca al completar la pulsacion sostenida.
  final VoidCallback onActivate;

  /// Cuanto hay que sostener para disparar.
  final Duration holdDuration;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onHoldStatus);

  bool get _isActive => widget.enabled && !widget.isSending;

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // No se toca el controller aca: modificarlo dentro de su propio callback
    // de estado interrumpe la notificacion y el SOS no llegaba a dispararse.
    // La barra vuelve a cero al soltar, en _cancelHold.
    HapticFeedback.heavyImpact();
    widget.onActivate();
  }

  void _startHold(_) {
    if (!_isActive) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _cancelHold([_]) {
    // Siempre revertir, sin condicionar por el valor actual: en un toque
    // rapido no llego a correr ningun frame, el valor sigue en 0 y una
    // guarda `value > 0` dejaba viva la animacion hacia adelante, de modo
    // que el toque terminaba disparando el SOS igual.
    _hold.reverse();
  }

  @override
  void dispose() {
    _hold.removeStatusListener(_onHoldStatus);
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = !widget.enabled
        ? l10n.sosBlocked
        : widget.isSending
            ? l10n.a11ySosButtonSending
            : l10n.sosHoldLabel;

    return Semantics(
      button: true,
      enabled: _isActive,
      label: widget.isSending
          ? l10n.a11ySosButtonSending
          : l10n.a11ySosEmergency,
      // El gesto real es sostener; para accesibilidad se expone tambien
      // como accion directa, sin obligar a mantener presionado.
      onTap: _isActive ? widget.onActivate : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: _startHold,
          onTapUp: _cancelHold,
          onTapCancel: _cancelHold,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _isActive
                  ? AppTheme.danger.withValues(alpha: 0.92)
                  : AppTheme.danger.withValues(alpha: 0.30),
              border: const Border(
                top: BorderSide(color: AppTheme.danger, width: 2),
              ),
            ),
            child: Stack(
              children: [
                // Relleno de progreso: muestra cuanto falta para disparar.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _hold.value,
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isSending)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
