import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';

/// Resumen de equipo de una noche: personas y áreas con actividad.
///
/// Es compartido por la tarjeta del administrador y la del empleado para que
/// ambas muestren las mismas métricas.
class TeamSummary extends StatelessWidget {
  final int people;
  final int areas;

  const TeamSummary({super.key, required this.people, required this.areas});

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
