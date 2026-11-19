import 'package:flutter/material.dart';

import '../../../formats.dart';
import '../../../shifts.dart';
import 'shift_timeline.dart';

/// Tarjeta con los turnos de un día, separados por planta.
///
/// Cada planta tiene su pestaña; dentro se muestra la línea temporal del
/// equipo. El pie recuerda al usuario qué puede hacer con los avatares.
class DayCard extends StatelessWidget {
  final String date;
  final List<Shift> shifts;
  final Map<int, String?> avatars;
  final bool isAdmin;
  final ValueChanged<Shift> onEdit;
  final ValueChanged<Shift> onDelete;

  const DayCard({
    super.key,
    required this.date,
    required this.shifts,
    required this.avatars,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total =
        shifts.fold<int>(0, (sum, shift) => sum + shift.workedMinutes);
    final byFloor = <Floor, List<Shift>>{};
    for (final shift in shifts) {
      byFloor.putIfAbsent(shift.floor, () => []).add(shift);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: DefaultTabController(
        length: Floor.values.length,
        child: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatLongDateIso(date),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${shifts.length} pers. · ${formatHours(total)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  TabBar(
                    controller: tabs,
                    tabs: [
                      for (final floor in Floor.values) Tab(text: floor.label),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: tabs,
                    builder: (context, _) {
                      final floor = Floor.values[tabs.index];
                      final floorShifts = byFloor[floor] ?? const <Shift>[];
                      if (floorShifts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text('Sin turnos en ${floor.label}.'),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ShiftTimeline(
                              shifts: floorShifts,
                              avatars: avatars,
                              onEdit: onEdit,
                              onDelete: onDelete,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAdmin
                                  ? 'Toca un avatar para editar · mantén '
                                      'pulsado para borrar'
                                  : 'Toca tu turno publicado para confirmarlo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
