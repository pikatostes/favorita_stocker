import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../models.dart';
import '../../../widgets/app_ui.dart';

/// Estado del mes y previsión, con las acciones de generar y publicar.
class AdminPlanningCard extends StatelessWidget {
  final HomeData data;
  final bool working;
  final VoidCallback onGenerate;
  final VoidCallback onPublish;

  const AdminPlanningCard({
    super.key,
    required this.data,
    required this.working,
    required this.onGenerate,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final counts = data.shiftCounts;
    final warnings = data.planningWarnings;
    final result = data.forecast;
    final items = result?.items.take(3).toList() ?? const <Forecast>[];

    return AppSectionCard(
      icon: Icons.event_note,
      title: 'Planificación · ${formatMonthLabel(data.month)}',
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                value: '${counts.drafts}',
                label: 'Borradores',
                icon: Icons.edit_note,
                tone: counts.drafts == 0 ? AppTone.neutral : AppTone.warning,
                dense: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppStatTile(
                value: '${counts.published}',
                label: 'Publicados',
                icon: Icons.publish,
                tone: AppTone.info,
                dense: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppStatTile(
                value: '${counts.confirmed}',
                label: 'Confirmados',
                icon: Icons.verified_outlined,
                tone: AppTone.success,
                dense: true,
              ),
            ),
          ],
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AlertBanner(
            title: 'Revisar planificación',
            message: warnings.join('\n'),
            tone: AppTone.warning,
            dense: true,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: working || !data.hasEligibleUsers ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generar mes'),
            ),
            OutlinedButton.icon(
              onPressed: working || counts.drafts == 0 ? null : onPublish,
              icon: const Icon(Icons.publish, size: 18),
              label: const Text('Publicar'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        _ForecastSection(data: data, result: result, items: items),
      ],
    );
  }
}

/// Previsión de consumo de la próxima noche, con las noches usadas como base.
class _ForecastSection extends StatelessWidget {
  final HomeData data;
  final ForecastResult? result;
  final List<Forecast> items;

  const _ForecastSection({
    required this.data,
    required this.result,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.insights, size: 17, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Previsión · ${formatShortDate(data.nextOpen)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (result != null)
              StatusPill(
                label: '${result!.recentNights} noches base',
                tone: AppTone.neutral,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          MutedText(
            result == null || result!.recentNights == 0
                ? 'Sin histórico suficiente para calcular la previsión.'
                : 'Sin productos con consumo registrado para esa noche.',
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${item.units} uds',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${item.boxes} cajas',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
