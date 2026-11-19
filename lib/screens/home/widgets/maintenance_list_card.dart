import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../widgets/app_ui.dart';

/// Aviso destacado para el puesto de mantenimiento. Sin sistema de
/// notificaciones, Inicio muestra si hay lista y abre el plan de montaje.
class MaintenanceListCard extends StatelessWidget {
  final HomeData data;
  final ValueChanged<NightListSummary> onOpen;

  const MaintenanceListCard({
    super.key,
    required this.data,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final list = data.nightList;
    final hasList = list != null;

    return Card(
      color: cs.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: list == null ? null : () => onOpen(list),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      hasList
                          ? Icons.inventory_2_outlined
                          : Icons.hourglass_empty,
                      color: cs.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lista de montaje',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasList
                              ? 'Guardada el ${formatLongDateIso(list.date)} · '
                                  '${list.floor.label}'
                              : 'Todavía no hay lista montada',
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                cs.onPrimaryContainer.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                    label: hasList ? 'Lista guardada' : 'Sin lista',
                    icon: hasList ? Icons.check_circle_outline : Icons.schedule,
                    tone: hasList ? AppTone.success : AppTone.neutral,
                    dense: true,
                  ),
                ],
              ),
              if (list != null) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _InfoChip(
                      icon: Icons.event_outlined,
                      label: formatShortDateIso(list.date),
                      foreground: cs.onPrimaryContainer,
                    ),
                    _InfoChip(
                      icon: Icons.stairs_outlined,
                      label: list.floor.label,
                      foreground: cs.onPrimaryContainer,
                    ),
                    _InfoChip(
                      icon: Icons.category_outlined,
                      label:
                          '${list.products} producto${list.products == 1 ? '' : 's'}',
                      foreground: cs.onPrimaryContainer,
                    ),
                    _InfoChip(
                      icon: Icons.local_drink_outlined,
                      label:
                          '${list.totalUnits} uds · ${list.fullBoxes.values.fold<int>(0, (a, b) => a + b)} cajas',
                      foreground: cs.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      'Ver plan de montaje',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 17,
                      color: cs.onPrimaryContainer,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground.withValues(alpha: 0.85)),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
}
