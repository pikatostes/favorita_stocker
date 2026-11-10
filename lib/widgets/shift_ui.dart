import 'package:flutter/material.dart';

import '../app_design.dart';
import '../shifts.dart';
import 'app_ui.dart';
import 'user_avatar.dart';

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
  Widget build(BuildContext context) => StatusPill(
        label: status.label,
        dense: true,
        icon: switch (status) {
          ShiftStatus.draft => Icons.edit_note,
          ShiftStatus.published => Icons.visibility_outlined,
          ShiftStatus.confirmed => Icons.verified_outlined,
        },
        tone: switch (status) {
          ShiftStatus.draft => AppTone.neutral,
          ShiftStatus.published => AppTone.info,
          ShiftStatus.confirmed => AppTone.success,
        },
      );
}

/// Pestañas por planta del local. Cada pestaña conserva el icono de su planta
/// y solo muestra los turnos de la planta seleccionada.
class FloorShiftTabs extends StatelessWidget {
  final List<Shift> shifts;

  /// Rutas de avatar por id de usuario para pintar las fotos del equipo.
  final Map<int, String?> avatars;

  final String emptyLabel;
  final Set<Floor> noOpener;

  const FloorShiftTabs({
    super.key,
    required this.shifts,
    this.avatars = const {},
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              for (final floor in Floor.values)
                Tab(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(floorIcon(floor), size: 17),
                      const SizedBox(width: 5),
                      Text(
                        floor.label,
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
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
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (floorShifts.isEmpty)
                          MutedText(emptyLabel)
                        else
                          _TeamGrid(shifts: floorShifts, avatars: avatars),
                        if (noOpener.contains(floor))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AlertBanner(
                              message: 'Sin opener en ${floor.label}.',
                              tone: AppTone.warning,
                              dense: true,
                            ),
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
  final Map<int, String?> avatars;

  const _TeamGrid({required this.shifts, required this.avatars});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 78).floor().clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 82,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemCount: shifts.length,
          itemBuilder: (context, index) => _MemberTile(
            shift: shifts[index],
            avatarPath: avatars[shifts[index].userId],
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Shift shift;
  final String? avatarPath;

  const _MemberTile({required this.shift, this.avatarPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = shift.userName.trim();
    return Semantics(
      label: '${name.isEmpty ? 'Sin nombre' : name}, ${shift.roleName}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          UserAvatar(
            path: avatarPath,
            name: name,
            radius: 21,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            textStyle: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
