import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/shift_ui.dart';

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
            '${next.positionName} · ${next.floor.label}',
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
