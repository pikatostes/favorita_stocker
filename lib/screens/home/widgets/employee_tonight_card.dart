import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/shift_ui.dart';
import 'team_summary.dart';

/// Equipo de la noche de foco tal como lo ve un empleado.
class EmployeeTonightCard extends StatelessWidget {
  final HomeData data;

  const EmployeeTonightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final shifts = data.publishedFocusShifts;
    final areas = shifts.map((shift) => shift.floor).toSet().length;
    final title =
        '${data.focusIsTonight ? 'Esta noche' : 'Próxima noche'} · ${formatShortDate(data.focusDay)}';
    return AppSectionCard(
      icon: Icons.groups,
      title: title,
      children: [
        TeamSummary(
          people: shifts.length,
          areas: areas,
        ),
        const SizedBox(height: AppSpacing.md),
        FloorShiftTabs(
          shifts: shifts,
          avatars: AppUser.avatarPaths(data.users),
          emptyLabel: 'Sin turnos publicados en esta planta.',
        ),
      ],
    );
  }
}
