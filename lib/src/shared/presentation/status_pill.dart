import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.isEmergency, super.key});

  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: isEmergency ? 'CRITICO' : 'OPERATIVO',
      color: isEmergency ? AppTheme.danger : AppTheme.success,
      icon: isEmergency ? Icons.priority_high : Icons.radio_button_checked,
    );
  }
}
