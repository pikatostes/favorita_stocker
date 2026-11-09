import 'package:flutter/material.dart';

import '../../app_design.dart';
import '../../formats.dart';
import '../../models.dart';
import '../../schedule.dart';
import '../../shifts.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/shift_ui.dart';
import 'home_data.dart';

/// Cabecera del Inicio con el saludo, el estado del bar y la próxima excepción
/// del calendario. Mantiene el logotipo reconocible sin que domine la pantalla.
class HomeHeader extends StatelessWidget {
  final HomeData data;
  final AppUser? user;

  const HomeHeader({super.key, required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = user?.role == UserRole.admin;
    final rawName =
        user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'equipo';
    final name = rawName.split(RegExp(r'\s+')).first;
    final status = _statusFor(data);

    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hola, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          formatLongDate(data.now),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final avatar = Tooltip(
      message: user?.fullName ?? 'Cuenta',
      child: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(
          user?.initial ?? '?',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppLogo(height: 26),
                        const Spacer(),
                        avatar,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    greeting,
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: status.label,
                          icon: status.icon,
                          tone: status.tone,
                        ),
                        Text(
                          status.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(height: 30),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: greeting),
                  const SizedBox(width: AppSpacing.lg),
                  StatusPill(
                    label: status.label,
                    icon: status.icon,
                    tone: status.tone,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    status.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  avatar,
                ],
              );
            },
          ),
          if (isAdmin) _NextSpecialLine(data: data),
        ],
      ),
    );
  }
}

class _HomeStatus {
  final String label;
  final String detail;
  final IconData icon;
  final AppTone tone;

  const _HomeStatus({
    required this.label,
    required this.detail,
    required this.icon,
    required this.tone,
  });
}

_HomeStatus _statusFor(HomeData data) {
  if (data.openNow) {
    return _HomeStatus(
      label: 'Abierto ahora',
      detail: 'Servicio ${formatShortDate(data.serviceDay)}',
      icon: Icons.nightlife,
      tone: AppTone.success,
    );
  }
  if (data.opensLaterToday) {
    return _HomeStatus(
      label: 'Abre esta noche',
      detail: formatShortDate(data.nextOpen),
      icon: Icons.schedule,
      tone: AppTone.warning,
    );
  }
  return _HomeStatus(
    label: 'Cerrado',
    detail: 'Próxima apertura ${formatShortDate(data.nextOpen)}',
    icon: Icons.nightlight_round,
    tone: AppTone.neutral,
  );
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
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
                              ? 'Guardada el ${formatLongDateIso(list.date)}'
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

/// Turnos de la noche de foco, con los avisos de plantas sin opener.
class AdminTonightCard extends StatelessWidget {
  final HomeData data;

  const AdminTonightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final drafts = data.countShifts(ShiftStatus.draft);
    final areas = data.focusShifts.map((shift) => shift.floor).toSet().length;
    final title =
        '${data.focusIsTonight ? 'Esta noche' : 'Próxima noche'} · ${formatShortDate(data.focusDay)}';

    return AppSectionCard(
      icon: Icons.nightlife,
      title: title,
      trailing: StatusPill(
        label: drafts == 0
            ? 'Sin borradores'
            : '$drafts borrador${drafts == 1 ? '' : 'es'}',
        tone: drafts == 0 ? AppTone.neutral : AppTone.warning,
        dense: true,
      ),
      children: [
        _TeamSummary(
          people: data.focusShifts.length,
          areas: areas,
        ),
        const SizedBox(height: AppSpacing.md),
        FloorShiftTabs(
          shifts: data.focusShifts,
          noOpener: data.floorsWithoutOpener,
          emptyLabel: 'Sin turnos generados en esta planta.',
        ),
      ],
    );
  }
}

/// Resumen de equipo de una noche: personas y áreas con actividad.
class _TeamSummary extends StatelessWidget {
  final int people;
  final int areas;

  const _TeamSummary({required this.people, required this.areas});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppStatTile(
            value: '$people',
            label: 'Personas',
            icon: Icons.groups_outlined,
            tone: AppTone.info,
            dense: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppStatTile(
            value: '$areas/${Floor.values.length}',
            label: 'Áreas',
            icon: Icons.storefront_outlined,
            tone: AppTone.neutral,
            dense: true,
          ),
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
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                value: '$draft',
                label: 'Borradores',
                icon: Icons.edit_note,
                tone: draft == 0 ? AppTone.neutral : AppTone.warning,
                dense: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppStatTile(
                value: '$published',
                label: 'Publicados',
                icon: Icons.publish,
                tone: AppTone.info,
                dense: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppStatTile(
                value: '$confirmed',
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
              onPressed: working || draft == 0 ? null : onPublish,
              icon: const Icon(Icons.publish, size: 18),
              label: const Text('Publicar'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
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
                label: '${result.recentNights} noches base',
                tone: AppTone.neutral,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          MutedText(
            result == null || result.recentNights == 0
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
      trailing: next == null ? null : ShiftStatusChip(status: next.status),
      children: [
        if (next == null)
          data.mySchedulePending
              ? const AlertBanner(
                  message: 'Tu horario está pendiente de publicación.',
                  tone: AppTone.info,
                  dense: true,
                )
              : const MutedText('No tienes turnos publicados.')
        else ...[
          Text(
            formatLongDateIso(next.date),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            next.timeLabel,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
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
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        if (next != null || myShifts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 17,
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
    final areas = data.publishedFocusShifts.map((s) => s.floor).toSet().length;
    final title =
        '${data.focusIsTonight ? 'Esta noche' : 'Próxima noche'} · ${formatShortDate(data.focusDay)}';
    return AppSectionCard(
      icon: Icons.groups,
      title: title,
      children: [
        _TeamSummary(
          people: data.publishedFocusShifts.length,
          areas: areas,
        ),
        const SizedBox(height: AppSpacing.md),
        FloorShiftTabs(
          shifts: data.publishedFocusShifts,
          emptyLabel: 'Sin turnos publicados en esta planta.',
        ),
      ],
    );
  }
}
