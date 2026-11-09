import 'package:flutter/material.dart';

import '../../formats.dart';
import '../../models.dart';
import '../../schedule.dart';
import '../../shifts.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/shift_ui.dart';
import 'home_data.dart';

/// Cabecera del Inicio con el saludo, el estado del bar y la próxima excepción
/// del calendario.
class HomeHeader extends StatelessWidget {
  final HomeData data;
  final AppUser? user;

  const HomeHeader({super.key, required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = user?.role == UserRole.admin;
    final name =
        user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'equipo';
    final statusText = data.openNow
        ? 'Abierto ahora · servicio ${formatShortDate(data.serviceDay)}'
        : data.opensLaterToday
            ? 'Abre esta noche · ${formatShortDate(data.nextOpen)}'
            : 'Cerrado · próxima apertura ${formatShortDate(data.nextOpen)}';
    final statusColor = data.openNow || data.opensLaterToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final statusIcon = data.openNow || data.opensLaterToday
        ? Icons.nightlife
        : Icons.nightlight_round;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(
                  user?.initial ?? '?',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $name',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatLongDate(data.now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (isAdmin) _NextSpecialLine(data: data),
        ],
      ),
    );
  }
}

class _NextSpecialLine extends StatelessWidget {
  final HomeData data;

  const _NextSpecialLine({required this.data});

  @override
  Widget build(BuildContext context) {
    final label = _nextSpecialLabel(data);
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _nextSpecialLabel(HomeData data) {
  final todayKey = Schedule.fmt(Schedule.day(data.now));
  final upcoming = data.special.entries
      .where((entry) => entry.key.compareTo(todayKey) >= 0)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (upcoming.isEmpty) return null;
  final entry = upcoming.first;
  final note = entry.value.note.trim();
  final action = entry.value.open ? 'apertura' : 'cierre';
  return 'Calendario: ${formatShortDateIso(entry.key)} · $action'
      '${note.isEmpty ? '' : ' · $note'}';
}

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
    final fg = cs.onPrimaryContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasList ? () => onOpen(list) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: hasList ? cs.primary : cs.surface,
                foregroundColor: hasList ? cs.onPrimary : cs.onSurfaceVariant,
                child: Icon(
                  hasList ? Icons.inventory_2_outlined : Icons.hourglass_empty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lista de montaje',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasList
                          ? 'Lista montada · '
                              '${formatShortDateIso(list.date)}'
                          : 'Todavía no hay lista montada',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasList
                          ? '${list.products} productos · '
                              '${list.totalUnits} botellines'
                          : 'Cuando alguien guarde la lista de la noche, '
                              'aparecerá aquí.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.78),
                      ),
                    ),
                    if (hasList) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Ver plan de montaje',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16, color: fg),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (hasList) Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Turnos de la noche de foco, con los avisos de plantas sin opener.
class AdminTonightCard extends StatelessWidget {
  final HomeData data;

  const AdminTonightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final drafts = data.countShifts(ShiftStatus.draft);
    final title = [
      data.focusIsTonight ? 'Esta noche' : 'Próxima noche',
      formatShortDate(data.focusDay),
      if (drafts > 0) drafts == 1 ? '1 borrador' : '$drafts borradores',
    ].join(' · ');

    return AppSectionCard(
      icon: Icons.nightlife,
      title: title,
      children: [
        FloorShiftTabs(
          shifts: data.focusShifts,
          noOpener: data.floorsWithoutOpener,
          emptyLabel: 'Sin turnos generados en esta planta.',
        ),
      ],
    );
  }
}

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
    final theme = Theme.of(context);
    final draft = data.countShifts(ShiftStatus.draft);
    final published = data.countShifts(ShiftStatus.published);
    final confirmed = data.countShifts(ShiftStatus.confirmed);
    final warnings = data.planningWarnings;
    final result = data.forecast;
    final items = result?.items.take(3).toList() ?? const <Forecast>[];

    return AppSectionCard(
      icon: Icons.event_note,
      title: 'Planificación · ${formatMonthLabel(data.month)}',
      children: [
        AppStatsRow(
          stats: [
            AppStat(
              value: '$draft',
              label: 'Borradores',
              color: theme.colorScheme.onSurfaceVariant,
            ),
            AppStat(
              value: '$published',
              label: 'Publicados',
              color: theme.colorScheme.primary,
            ),
            AppStat(
              value: '$confirmed',
              label: 'Confirmados',
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: WarningLine(warnings.join(' · ')),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: working || !data.hasEligibleUsers ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar mes'),
            ),
            OutlinedButton.icon(
              onPressed: working || draft == 0 ? null : onPublish,
              icon: const Icon(Icons.publish),
              label: const Text('Publicar'),
            ),
          ],
        ),
        const Divider(height: 22),
        Row(
          children: [
            Icon(Icons.insights, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Previsión · ${formatShortDate(data.nextOpen)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          MutedText(
            result == null || result.recentNights == 0
                ? 'Sin histórico suficiente para calcular la previsión.'
                : 'Sin productos con consumo registrado para esa noche.',
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${item.units} uds',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.boxes} cajas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Próximo turno del empleado y horas publicadas del mes.
class MyDayCard extends StatelessWidget {
  final HomeData data;
  final AppUser? user;

  const MyDayCard({super.key, required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = data.myUpcoming.isEmpty ? null : data.myUpcoming.first;
    final myShifts = data.monthShifts
        .where((shift) =>
            shift.userId == user?.id && shift.status != ShiftStatus.draft)
        .toList(growable: false);
    final total = myShifts.fold<int>(
      0,
      (sum, shift) => sum + shift.workedMinutes,
    );
    final hoursLabel = myShifts.isEmpty
        ? 'Sin horas publicadas este mes'
        : 'Este mes: ${formatHours(total)} · '
            '${myShifts.length} turno${myShifts.length == 1 ? '' : 's'}';

    return AppSectionCard(
      icon: Icons.event_available,
      title: 'Mi turno',
      children: [
        if (next == null)
          MutedText(
            data.mySchedulePending
                ? 'Tu horario está pendiente de publicación.'
                : 'No tienes turnos publicados.',
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  formatLongDateIso(next.date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ShiftStatusChip(status: next.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            next.timeLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${next.roleName} · ${next.floor.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (data.myUpcoming.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${data.myUpcoming.length - 1} turnos más publicados',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (next != null || myShifts.isNotEmpty) ...[
          const Divider(height: 18),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hoursLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Equipo de la noche de foco tal como lo ve un empleado.
class EmployeeTonightCard extends StatelessWidget {
  final HomeData data;

  const EmployeeTonightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = [
      data.focusIsTonight ? 'Esta noche' : 'Próxima noche',
      formatShortDate(data.focusDay),
    ].join(' · ');
    return AppSectionCard(
      icon: Icons.groups,
      title: title,
      children: [
        FloorShiftTabs(
          shifts: data.publishedFocusShifts,
          emptyLabel: 'Sin turnos publicados en esta planta.',
        ),
      ],
    );
  }
}
