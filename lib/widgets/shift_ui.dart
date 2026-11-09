import 'package:flutter/material.dart';

import '../shifts.dart';
import 'app_ui.dart';

/// Icono que representa una planta del local.
IconData floorIcon(Floor floor) => switch (floor) {
      Floor.plantaBaja => Icons.storefront,
      Floor.karaoke => Icons.mic,
      Floor.terraza => Icons.deck,
    };

/// Etiqueta con el estado de un turno, con el color de su estado.
class ShiftStatusChip extends StatelessWidget {
  final ShiftStatus status;

  const ShiftStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      ShiftStatus.draft => theme.colorScheme.onSurfaceVariant,
      ShiftStatus.published => theme.colorScheme.primary,
      ShiftStatus.confirmed => theme.colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Pestañas por planta del local. Cada pestaña conserva el icono de su planta
/// y solo muestra los turnos de la planta seleccionada.
class FloorShiftTabs extends StatelessWidget {
  final List<Shift> shifts;
  final String emptyLabel;
  final Set<Floor> noOpener;

  const FloorShiftTabs({
    super.key,
    required this.shifts,
    required this.emptyLabel,
    this.noOpener = const {},
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: Floor.values.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              for (final floor in Floor.values)
                Tab(icon: Icon(floorIcon(floor)), text: floor.label),
            ],
          ),
          Builder(
            builder: (context) {
              final tabs = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: tabs,
                builder: (context, _) {
                  final floor = Floor.values[tabs.index];
                  final floorShifts = shifts
                      .where((shift) => shift.floor == floor)
                      .toList(growable: false);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (floorShifts.isEmpty)
                          MutedText(emptyLabel)
                        else
                          _TeamGrid(shifts: floorShifts),
                        if (noOpener.contains(floor))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: WarningLine('Sin opener en ${floor.label}.'),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Miembros de la planta en una rejilla de avatares con su nombre debajo.
class _TeamGrid extends StatelessWidget {
  final List<Shift> shifts;

  const _TeamGrid({required this.shifts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisExtent: 80,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
      ),
      itemCount: shifts.length,
      itemBuilder: (context, index) => _MemberTile(shift: shifts[index]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Shift shift;

  const _MemberTile({required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = shift.userName.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          child: Text(
            initial,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
