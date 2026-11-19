import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/schedule_data.dart';
import '../../../formats.dart';
import '../../../schedule.dart';
import '../../../shifts.dart';
import '../../../widgets/month_calendar.dart';
import 'day_card.dart';

/// Composición visual de la pestaña Horario.
///
/// Recibe los datos ya cargados y todos los callbacks: no consulta la base de
/// datos ni guarda estado. El calendario ocupa la columna izquierda en tablet
/// y escritorio; en móvil todo se apila en una sola columna.
class ScheduleView extends StatelessWidget {
  final ScheduleData data;
  final bool isAdmin;
  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onGoToday;
  final VoidCallback onGenerate;
  final VoidCallback onPublish;
  final ValueChanged<Shift> onEditShift;
  final ValueChanged<Shift> onDeleteShift;
  final Future<void> Function(List<Shift> shifts) onCreateShifts;

  const ScheduleView({
    super.key,
    required this.data,
    required this.isAdmin,
    required this.month,
    required this.selected,
    required this.onSelectDay,
    required this.onMonthChanged,
    required this.onGoToday,
    required this.onGenerate,
    required this.onPublish,
    required this.onEditShift,
    required this.onDeleteShift,
    required this.onCreateShifts,
  });

  CalendarDayStyle _dayStyle(BuildContext context, DateTime day) {
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final special = data.special[key];
    if (data.shiftsFor(key).isNotEmpty) {
      return CalendarDayStyle(fill: cs.primary, textColor: cs.onPrimary);
    }
    if (special != null && !special.open) {
      return CalendarDayStyle(
        fill: cs.errorContainer,
        textColor: cs.onErrorContainer,
      );
    }
    if (Schedule.isOpen(day, data.special)) {
      return CalendarDayStyle(
        border: Border.all(color: cs.primary, width: 1.5),
      );
    }
    return const CalendarDayStyle();
  }

  Widget? _dayFooter(BuildContext context, DateTime day) {
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final shifts = data.shiftsFor(key);
    if (shifts.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${shifts.length}',
          style: TextStyle(
            fontSize: 8,
            height: 1.2,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (data.special.containsKey(key)) {
      return Icon(Icons.circle, size: 6, color: cs.tertiary);
    }
    return null;
  }

  Widget _legend(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget dot({Color? color, Color? border}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border:
                border == null ? null : Border.all(color: border, width: 1.5),
          ),
        );
    Widget item(Widget mark, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 11)),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(dot(color: cs.primary), 'Con turnos'),
        item(dot(border: cs.primary), 'Abre sin turnos'),
        item(dot(color: cs.errorContainer), 'Cerrado (excepción)'),
        item(
          Icon(Icons.circle, size: 6, color: cs.tertiary),
          'Excepción',
        ),
      ],
    );
  }

  Widget _dayDetails(BuildContext context) {
    final key = Schedule.fmt(selected);
    final shifts = data.shiftsFor(key);
    if (shifts.isNotEmpty) {
      return DayCard(
        date: key,
        shifts: shifts,
        users: data.users,
        avatars: AppUser.avatarPaths(data.users),
        isAdmin: isAdmin,
        onEdit: onEditShift,
        onDelete: onDeleteShift,
        onAddShifts: onCreateShifts,
      );
    }

    final special = data.special[key];
    final open = Schedule.isOpen(selected, data.special);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatLongDateIso(key),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              open ? 'Sin turnos para este día.' : 'El bar no abre este día.',
            ),
            if (special != null && special.note.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                special.note.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Calendario del mes con sus acciones y la leyenda.
  Widget _calendarColumn(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonthCalendar(
            month: month,
            selected: selected,
            onSelect: onSelectDay,
            onMonthChanged: onMonthChanged,
            styleFor: (day) => _dayStyle(context, day),
            footerFor: (day) => _dayFooter(context, day),
            cellHeight: 50,
            headerActions: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (isAdmin) ...[
                  FilledButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar mes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: data.shifts.isEmpty ? null : onPublish,
                    icon: const Icon(Icons.publish),
                    label: const Text('Publicar'),
                  ),
                ],
                TextButton.icon(
                  onPressed: onGoToday,
                  icon: const Icon(Icons.today),
                  label: const Text('Hoy'),
                ),
              ],
            ),
          ),
          if (!data.hasUsers)
            Card(
              margin: const EdgeInsets.only(top: AppSpacing.md),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  isAdmin
                      ? 'Añade puestos en «Puestos» y usuarios en '
                          '«Usuarios» para poder generar el horario.'
                      : 'Todavía no hay usuarios con un puesto asignado.',
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _legend(context),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final calendar = _calendarColumn(context);
    final details = _dayDetails(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.contentMaxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dos columnas en tablet y escritorio: el calendario a la
            // izquierda y los turnos del día elegido a la derecha. En móvil
            // se mantiene una única columna apilada.
            final wide = constraints.maxWidth >= AppBreakpoints.tabletMin;

            if (!wide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: [
                  calendar,
                  const SizedBox(height: AppSpacing.md),
                  details,
                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(child: calendar),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: details),
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
