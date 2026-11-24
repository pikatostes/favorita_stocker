import 'package:flutter/material.dart';

import '../../../auth_controller.dart';
import '../../../data/schedule_data.dart';
import '../../../data/schedule_repository.dart';
import '../../../db.dart';
import '../../../formats.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import 'schedule_dates.dart';
import 'schedule_view.dart';
import 'shift_dialog.dart';

/// Pestaña Horario.
///
/// Mantiene el mes y el día seleccionados, carga los turnos y ejecuta las
/// acciones de planificación (generar, publicar, editar) y la confirmación de
/// turnos por parte del empleado. La composición visual está en
/// [ScheduleView].
class ScheduleTab extends StatefulWidget {
  final bool isAdmin;

  const ScheduleTab({super.key, required this.isAdmin});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = initialSelectedDay();
  late Future<ScheduleData> _future = _load();
  late final VoidCallback _stopWatching;

  Future<ScheduleData> _load() => ScheduleRepository.i.loadMonth(_month);

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  @override
  void initState() {
    super.initState();
    _stopWatching = Db.i.watchTables(
      {'shift', 'special_day', ...Db.userTables},
      _reload,
    );
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  void _goToday() {
    final next = nextOpenDay(DateTime.now());
    setState(() {
      _month = DateTime(next.year, next.month);
      _selected = next;
      _future = _load();
    });
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _month = month;
      _selected = firstOpenDay(month);
      _future = _load();
    });
  }

  Future<void> _generate() async {
    ScheduleData data;
    try {
      data = await _load();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudieron cargar los turnos: ${describeDbError(error)}',
      );
      return;
    }
    if (!mounted) return;
    final eligibleUsers = data.usersWithRole;
    if (eligibleUsers.isEmpty) {
      showAppSnack(
        context,
        'Añade al menos un usuario con puesto en la pestaña «Usuarios» '
        'para generar.',
      );
      return;
    }

    if (data.shifts.isNotEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Regenerar el mes',
        message: 'Se borrarán los ${data.shifts.length} turnos de este mes y '
            'se crearán de nuevo a partir de los usuarios.',
        confirmLabel: 'Generar',
      );
      if (!ok || !mounted) return;
    }

    final generated = ShiftGenerator.generateMonth(
      month: _month,
      users: eligibleUsers,
      specialDays: data.special,
    );
    if (generated.isNotEmpty && mounted) {
      setState(() => _selected = DateTime.parse(generated.first.date));
    }
    try {
      await Db.i.replaceMonthShifts(_month, generated);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudieron generar los turnos: ${describeDbError(error)}',
      );
      return;
    }
    if (!mounted) return;
    showAppSnack(context, 'Generados ${generated.length} turnos.');
  }

  Future<void> _publish() async {
    try {
      await Db.i.publishMonth(_month);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudieron publicar los turnos: ${describeDbError(error)}',
      );
      return;
    }
    if (!mounted) return;
    showAppSnack(context, 'Turnos publicados.');
  }

  /// Tocar un turno: el admin lo edita; el empleado confirma el suyo.
  Future<void> _onShiftTap(Shift shift) async {
    if (widget.isAdmin) {
      await _editShift(shift);
      return;
    }
    final me = AuthController.i.user;
    if (me == null) return;
    if (shift.userId != me.id) {
      showAppSnack(context, 'Solo puedes confirmar tus propios turnos.');
      return;
    }
    if (shift.status == ShiftStatus.confirmed) {
      showAppSnack(context, 'Este turno ya está confirmado.');
      return;
    }
    if (shift.status != ShiftStatus.published) {
      showAppSnack(context, 'El turno todavía no está publicado.');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: 'Confirmar turno',
      message: '${formatLongDateIso(shift.date)} · ${shift.timeLabel}\n'
          '${shift.positionName} (${shift.floor.label})',
      confirmLabel: 'Confirmar',
    );
    if (!ok || !mounted) return;

    try {
      await Db.i.confirmShift(shift.id!);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo confirmar el turno: ${describeDbError(error)}',
      );
      return;
    }
    if (!mounted) return;
    showAppSnack(context, 'Turno confirmado.');
  }

  void _onShiftLongPress(Shift shift) {
    if (widget.isAdmin) _deleteShift(shift);
  }

  Future<void> _editShift(Shift shift) async {
    final updated = await showDialog<Shift>(
      context: context,
      builder: (_) => ShiftDialog(shift: shift),
    );
    if (updated == null) return;
    try {
      await Db.i.updateShift(updated);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo guardar el turno: ${describeDbError(error)}',
      );
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final ok = await showConfirmDialog(
      context,
      title: '¿Borrar el turno de ${shift.userName}?',
      message: '${formatLongDateIso(shift.date)} · ${shift.timeLabel}',
      confirmLabel: 'Borrar',
    );
    if (!ok) return;
    try {
      await Db.i.deleteShift(shift.id!);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo borrar el turno: ${describeDbError(error)}',
      );
    }
  }

  /// Guarda los turnos creados desde los diálogos de franja del [DayCard].
  Future<void> _createShifts(List<Shift> shifts) async {
    if (shifts.isEmpty) return;
    try {
      await Db.i.addShifts(shifts);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudieron añadir los turnos: ${describeDbError(error)}',
      );
      return;
    }
    if (!mounted) return;
    showAppSnack(
      context,
      '${shifts.length} turno${shifts.length == 1 ? '' : 's'} añadido'
      '${shifts.length == 1 ? '' : 's'}.',
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScheduleData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'No se pudieron cargar los turnos.',
              error: snapshot.error!,
              onRetry: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const AppLoadingState(label: 'Cargando horario…');
          }
          return ScheduleView(
            data: snapshot.data!,
            isAdmin: widget.isAdmin,
            month: _month,
            selected: _selected,
            onSelectDay: (day) => setState(() => _selected = day),
            onMonthChanged: _changeMonth,
            onGoToday: _goToday,
            onGenerate: _generate,
            onPublish: _publish,
            onEditShift: _onShiftTap,
            onDeleteShift: _onShiftLongPress,
            onCreateShifts: _createShifts,
          );
        },
      );
}
