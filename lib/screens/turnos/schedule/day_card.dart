import 'package:flutter/material.dart';

import '../../../formats.dart';
import '../../../shifts.dart';
import 'add_people_dialog.dart';
import 'new_slot_dialog.dart';
import 'shift_timeline.dart';

/// Tarjeta con los turnos de un día, separados por planta.
///
/// Cada planta tiene su pestaña; dentro se muestra la línea temporal del
/// equipo. El administrador puede crear franjas nuevas y añadir personas a una
/// franja existente. Una franja no se guarda por separado: existe mientras
/// tenga al menos un turno, así que al borrar a su última persona desaparece.
class DayCard extends StatelessWidget {
  final String date;
  final List<Shift> shifts;
  final List<AppUser> users;
  final Map<int, String?> avatars;
  final bool isAdmin;
  final ValueChanged<Shift> onEdit;
  final ValueChanged<Shift> onDelete;
  final Future<void> Function(List<Shift> shifts) onAddShifts;

  const DayCard({
    super.key,
    required this.date,
    required this.shifts,
    required this.users,
    required this.avatars,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
    required this.onAddShifts,
  });

  Future<void> _openNewSlot(BuildContext context, Floor floor) async {
    final created = await showDialog<List<Shift>>(
      context: context,
      builder: (_) => NewSlotDialog(
        date: date,
        floor: floor,
        users: users,
        dayShifts: shifts,
      ),
    );
    if (created == null || created.isEmpty) return;
    await onAddShifts(created);
  }

  Future<void> _openAddPeople(
    BuildContext context,
    Floor floor,
    List<Shift> floorShifts,
  ) async {
    final created = await showDialog<List<Shift>>(
      context: context,
      builder: (_) => AddPeopleDialog(
        date: date,
        floor: floor,
        users: users,
        floorShifts: floorShifts,
        dayShifts: shifts,
      ),
    );
    if (created == null || created.isEmpty) return;
    await onAddShifts(created);
  }

  Widget _adminActions(
    BuildContext context,
    Floor floor,
    List<Shift> floorShifts,
  ) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _openNewSlot(context, floor),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva franja'),
            ),
            OutlinedButton.icon(
              onPressed: floorShifts.isEmpty
                  ? null
                  : () => _openAddPeople(context, floor, floorShifts),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Añadir personas'),
            ),
          ],
        ),
      );

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

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isAdmin)
                              _adminActions(context, floor, floorShifts),
                            if (floorShifts.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    'Sin turnos en ${floor.label}.',
                                  ),
                                ),
                              )
                            else ...[
                              if (isAdmin) const SizedBox(height: 8),
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
