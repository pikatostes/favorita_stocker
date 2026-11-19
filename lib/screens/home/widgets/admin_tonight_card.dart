import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/shift_ui.dart';
import 'team_summary.dart';

/// Turnos de la noche de foco, con los avisos de plantas sin opener.
class AdminTonightCard extends StatelessWidget {
  final HomeData data;

  const AdminTonightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final drafts = data.shiftCounts.drafts;
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
        TeamSummary(
          people: data.focusShifts.length,
          areas: areas,
        ),
        const SizedBox(height: AppSpacing.md),
        FloorShiftTabs(
          shifts: data.focusShifts,
          avatars: AppUser.avatarPaths(data.users),
          noOpener: data.floorsWithoutOpener,
          emptyLabel: 'Sin turnos generados en esta planta.',
        ),
      ],
    );
  }
}
