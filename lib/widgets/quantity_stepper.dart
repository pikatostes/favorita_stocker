import 'package:flutter/material.dart';

import '../app_design.dart';

/// Contador táctil reutilizable para cajas y unidades sueltas.
///
/// Mantiene botones de 44×44 px aunque el aspecto sea compacto, para que
/// funcionen bien en móvil y tablet sin perder precisión.
class QuantityStepper extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final String? hint;

  const QuantityStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 5),
                Text(
                  hint!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Container(
            height: AppSizes.controlHeight + 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepButton(
                  icon: Icons.remove,
                  tooltip: 'Quitar $label',
                  enabled: onDecrement != null,
                  onTap: onDecrement,
                ),
                Container(
                  width: 48,
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: value > 0
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add,
                  tooltip: 'Añadir $label',
                  enabled: true,
                  onTap: onIncrement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: 44,
            height: AppSizes.controlHeight + 4,
            child: Icon(
              icon,
              size: 19,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ),
      ),
    );
  }
}
