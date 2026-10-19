import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
import '../shifts.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _dateLabel(String date) =>
    _cap(DateFormat('EEEE d MMMM', 'es').format(DateTime.parse(date)));

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Primer viernes o sábado a partir de [from] (incluido).
DateTime _nextOpenDay(DateTime from) {
  var d = _day(from);
  for (var i = 0; i < 14; i++) {
    if (Schedule.openWeekdays.contains(d.weekday)) return d;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return _day(from);
}

/// Primer viernes o sábado del mes.
DateTime _firstOpenDay(DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= days; day++) {
    final d = DateTime(month.year, month.month, day);
    if (Schedule.openWeekdays.contains(d.weekday)) return d;
  }
  return DateTime(month.year, month.month, 1);
}

/// Día seleccionado al abrir la pestaña: hoy si el bar abre; si no, el próximo
/// viernes/sábado del mes o el primero del mes si el próximo cae en otro mes.
DateTime _initialSelectedDay() {
  final now = _day(DateTime.now());
  if (Schedule.openWeekdays.contains(now.weekday)) return now;
  final next = _nextOpenDay(now);
  return next.month == now.month ? next : _firstOpenDay(now);
}

IconData _floorIcon(Floor floor) => switch (floor) {
      Floor.plantaBaja => Icons.storefront,
      Floor.karaoke => Icons.mic,
      Floor.terraza => Icons.deck,
    };

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Pestaña "Turnos": horario mensual, empleados y puestos.
class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});
  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Turnos'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Horario'),
              Tab(text: 'Empleados'),
              Tab(text: 'Puestos'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _ScheduleTab(),
            _EmployeesTab(),
            _RolesTab(),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Horario
// ---------------------------------------------------------------------------

class _ScheduleData {
  final List<Shift> shifts;
  final List<Employee> employees;
  final Map<String, SpecialDay> special;
  _ScheduleData(this.shifts, this.employees, this.special);
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();
  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = _initialSelectedDay();
  late Future<_ScheduleData> _future = _load();

  Future<_ScheduleData> _load() async {
    // Las tres consultas son independientes: se lanzan a la vez.
    final shiftsF = Db.i.shiftsForMonth(_month);
    final employeesF = Db.i.employees();
    final specialF = Db.i.specialDays();
    return _ScheduleData(await shiftsF, await employeesF, await specialF);
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  void _goMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _selected = _firstOpenDay(_month);
        _future = _load();
      });

  void _goToday() {
    final next = _nextOpenDay(DateTime.now());
    setState(() {
      _month = DateTime(next.year, next.month);
      _selected = next;
      _future = _load();
    });
  }

  Future<void> _generate() async {
    final data = await _load();
    if (!mounted) return;
    if (data.employees.isEmpty) {
      _snack(context,
          'Añade al menos un empleado en la pestaña «Empleados» para generar.');
      return;
    }

    if (data.shifts.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerar el mes'),
          content: Text(
              'Se borrarán los ${data.shifts.length} turnos de este mes y se '
              'crearán de nuevo a partir de los empleados.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Generar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final generated = ShiftGenerator.generateMonth(
      month: _month,
      employees: data.employees,
      specialDays: data.special,
    );
    if (generated.isNotEmpty && mounted) {
      setState(() => _selected = DateTime.parse(generated.first.date));
    }
    await Db.i.replaceMonthShifts(_month, generated);
    if (!mounted) return;
    _snack(context, 'Generados ${generated.length} turnos.');
  }

  Future<void> _publish() async {
    await Db.i.publishMonth(_month);
    if (!mounted) return;
    _snack(context, 'Turnos publicados.');
  }

  Future<void> _editShift(Shift shift) async {
    final updated = await showDialog<Shift>(
      context: context,
      builder: (_) => _ShiftDialog(shift: shift),
    );
    if (updated == null) return;
    try {
      await Db.i.updateShift(updated);
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo guardar el turno: $e');
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar el turno de ${shift.employeeName}?'),
        content: Text('${_dateLabel(shift.date)} · ${shift.timeLabel}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await Db.i.deleteShift(shift.id!);
  }

  Widget _monthHeader() => Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _goMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                _cap(DateFormat('MMMM yyyy', 'es').format(_month)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _goMonth(1),
          ),
        ],
      );

  Widget _calendar(
    _ScheduleData data,
    Map<String, List<Shift>> byDate,
  ) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_month.year, _month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length; row += 7)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _calendarCell(cells[row + col], data, byDate),
                ),
            ],
          ),
      ],
    );
  }

  Widget _calendarCell(
    DateTime? day,
    _ScheduleData data,
    Map<String, List<Shift>> byDate,
  ) {
    if (day == null) return const SizedBox(height: 50);
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final shifts = byDate[key] ?? const <Shift>[];
    final special = data.special[key];
    final open = Schedule.isOpen(day, data.special);
    final today = _day(DateTime.now()) == day;
    final selected = _selected == day;
    final hasShifts = shifts.isNotEmpty;

    Color? fill;
    var textColor = cs.onSurface;
    Border? border;
    if (hasShifts) {
      fill = cs.primary;
      textColor = cs.onPrimary;
    } else if (special != null && !special.open) {
      fill = cs.errorContainer;
      textColor = cs.onErrorContainer;
    } else if (open) {
      border = Border.all(color: cs.primary, width: 1.5);
    }
    if (selected) {
      border = Border.all(color: cs.onSurface, width: 2.5);
    }

    return InkWell(
      onTap: () => setState(() => _selected = day),
      child: SizedBox(
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: border,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: today ? FontWeight.w900 : FontWeight.normal,
                  decoration: today ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (hasShifts)
              Container(
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
              )
            else if (special != null)
              Icon(Icons.circle, size: 6, color: cs.tertiary),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
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

  Widget _dayDetails(
    _ScheduleData data,
    Map<String, List<Shift>> byDate,
  ) {
    final key = Schedule.fmt(_selected);
    final shifts = byDate[key] ?? const <Shift>[];
    if (shifts.isNotEmpty) {
      return _DayCard(
        date: key,
        shifts: shifts,
        onEdit: _editShift,
        onDelete: _deleteShift,
      );
    }

    final special = data.special[key];
    final open = Schedule.isOpen(_selected, data.special);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel(key),
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

  Widget _hoursSummary(_ScheduleData data) {
    final byEmployee = <int, ({String name, int minutes})>{};
    for (final e in data.employees) {
      byEmployee[e.id!] = (name: e.name, minutes: 0);
    }
    for (final s in data.shifts) {
      final current = byEmployee[s.employeeId];
      byEmployee[s.employeeId] = (
        name: s.employeeName,
        minutes: (current?.minutes ?? 0) + s.workedMinutes,
      );
    }
    final rows = byEmployee.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final total = rows.fold<int>(0, (sum, r) => sum + r.minutes);

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Horas del mes'),
        subtitle: Text('${formatHours(total)} en total'),
        children: [
          for (final row in rows)
            ListTile(
              dense: true,
              title: Text(row.name),
              trailing: Text(
                formatHours(row.minutes),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ScheduleData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child:
                  Text('No se pudieron cargar los turnos: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final byDate = <String, List<Shift>>{};
          for (final shift in data.shifts) {
            byDate.putIfAbsent(shift.date, () => []).add(shift);
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _monthHeader(),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar mes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: data.shifts.isEmpty ? null : _publish,
                    icon: const Icon(Icons.publish),
                    label: const Text('Publicar'),
                  ),
                  TextButton.icon(
                    onPressed: _goToday,
                    icon: const Icon(Icons.today),
                    label: const Text('Hoy'),
                  ),
                ],
              ),
              if (data.employees.isEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Añade puestos en «Puestos» y empleados en «Empleados» '
                      'para poder generar el horario.',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _calendar(data, byDate),
              const SizedBox(height: 4),
              _legend(),
              const SizedBox(height: 8),
              _dayDetails(data, byDate),
              if (data.shifts.isNotEmpty) _hoursSummary(data),
              const SizedBox(height: 80),
            ],
          );
        },
      );
}

class _DayCard extends StatelessWidget {
  final String date;
  final List<Shift> shifts;
  final ValueChanged<Shift> onEdit;
  final ValueChanged<Shift> onDelete;

  const _DayCard({
    required this.date,
    required this.shifts,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = shifts.fold<int>(0, (sum, s) => sum + s.workedMinutes);
    final byFloor = <Floor, List<Shift>>{};
    for (final shift in shifts) {
      byFloor.putIfAbsent(shift.floor, () => []).add(shift);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateLabel(date),
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
            for (final floor in Floor.values)
              if (byFloor[floor] != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        _floorIcon(floor),
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        floor.label,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                for (final shift in byFloor[floor]!)
                  _ShiftTile(
                    shift: shift,
                    onEdit: () => onEdit(shift),
                    onDelete: () => onDelete(shift),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftTile({
    required this.shift,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final note = shift.note.trim();
    final breakText =
        shift.breakMin > 0 ? ' · ${shift.breakMin} min descanso' : '';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 22, right: 0),
      leading: Icon(
        Icons.person_outline,
        size: 20,
        color: Theme.of(context).colorScheme.outline,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              shift.employeeName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          _StatusBadge(status: shift.status),
        ],
      ),
      subtitle: Text(
        '${shift.roleName} · ${shift.timeLabel} · ${shift.hoursLabel}'
        '$breakText${note.isEmpty ? '' : '\n$note'}',
      ),
      isThreeLine: note.isNotEmpty,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onDelete,
      ),
      onTap: onEdit,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ShiftStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      ShiftStatus.draft => cs.outline,
      ShiftStatus.published => cs.primary,
      ShiftStatus.confirmed => cs.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShiftDialog extends StatefulWidget {
  final Shift shift;
  const _ShiftDialog({required this.shift});

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late int _start = widget.shift.startMin;
  late int _end = widget.shift.endMin;
  late ShiftStatus _status = widget.shift.status;
  late final TextEditingController _note =
      TextEditingController(text: widget.shift.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (!mounted || picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _save() {
    if (_start == _end) {
      _snack(context, 'La entrada y la salida no pueden ser iguales.');
      return;
    }
    Navigator.pop(
      context,
      Shift(
        id: widget.shift.id,
        date: widget.shift.date,
        employeeId: widget.shift.employeeId,
        employeeName: widget.shift.employeeName,
        roleId: widget.shift.roleId,
        roleName: widget.shift.roleName,
        floor: widget.shift.floor,
        startMin: _start,
        endMin: _end,
        breakMin: breakMinutesFor(startMin: _start, endMin: _end),
        status: _status,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = shiftDurationMinutes(_start, _end);
    final breakMin = breakMinutesFor(startMin: _start, endMin: _end);
    final worked = duration - breakMin;
    return AlertDialog(
      title: const Text('Editar turno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.shift.employeeName} · ${widget.shift.roleName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _dateLabel(widget.shift.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: true),
                    icon: const Icon(Icons.login),
                    label: Text(formatMinutes(_start)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: false),
                    icon: const Icon(Icons.logout),
                    label: Text(formatMinutes(_end)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Duración: ${formatHours(duration)} · '
              'Descanso: ${breakMin == 0 ? 'ninguno' : '$breakMin min'} · '
              'Trabajado: ${formatHours(worked)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ShiftStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                for (final status in ShiftStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota del turno'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empleados
// ---------------------------------------------------------------------------

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();
  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  late Future<List<Employee>> _future = Db.i.employees(includeInactive: true);

  void _reload() {
    if (mounted) {
      setState(() => _future = Db.i.employees(includeInactive: true));
    }
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  Future<void> _edit([Employee? employee]) async {
    final roles = await Db.i.roles();
    if (!mounted) return;
    if (roles.isEmpty) {
      _snack(context, 'Crea primero un puesto en la pestaña «Puestos».');
      return;
    }
    final result = await showDialog<Employee>(
      context: context,
      builder: (_) => _EmployeeDialog(employee: employee, roles: roles),
    );
    if (result == null) return;
    try {
      if (employee == null) {
        await Db.i.addEmployee(result);
      } else {
        await Db.i.updateEmployee(result);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo guardar el empleado: $e');
    }
  }

  Future<void> _toggle(Employee employee) async {
    try {
      await Db.i.setEmployeeActive(employee.id!, !employee.active);
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo cambiar el estado: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<Employee>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los empleados: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final employees = snapshot.data!;
            if (employees.isEmpty) {
              return const Center(
                child: Text('Añade tu primer empleado con +'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final employee = employees[index];
                final initial = employee.name.trim().isEmpty
                    ? '?'
                    : employee.name.trim()[0].toUpperCase();
                return ListTile(
                  leading: CircleAvatar(child: Text(initial)),
                  title: Text(
                    employee.name,
                    style: employee.active
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.lineThrough),
                  ),
                  subtitle: Text(
                    '${employee.role.name} · ${employee.role.floor.label}\n'
                    '${employee.workingDaysLabel}'
                    '${employee.opener ? ' · Puede abrir' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: employee.active,
                    onChanged: (_) => _toggle(employee),
                  ),
                  onTap: () => _edit(employee),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _edit(),
          child: const Icon(Icons.person_add),
        ),
      );
}

class _EmployeeDialog extends StatefulWidget {
  final Employee? employee;
  final List<JobRole> roles;

  const _EmployeeDialog({required this.employee, required this.roles});

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.employee?.name ?? '');
  late JobRole _role = widget.roles.firstWhere(
    (r) => r.id == widget.employee?.role.id,
    orElse: () => widget.roles.first,
  );
  late bool _active = widget.employee?.active ?? true;
  late bool _opener = widget.employee?.opener ?? false;
  late final Set<int> _workingDays = {...?widget.employee?.workingDays};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack(context, 'El nombre del empleado es obligatorio.');
      return;
    }
    Navigator.pop(
      context,
      Employee(
        id: widget.employee?.id,
        name: name,
        role: _role,
        active: _active,
        opener: _opener,
        workingDays: _workingDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.employee == null ? 'Nuevo empleado' : 'Editar empleado',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              DropdownButtonFormField<JobRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Puesto'),
                items: [
                  for (final role in widget.roles)
                    DropdownMenuItem(
                      value: role,
                      child: Text(
                        '${role.name} · ${role.floor.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Puede abrir'),
                subtitle: const Text('Puede abrir el bar o su planta.'),
                value: _opener,
                onChanged: (value) => setState(() => _opener = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Días que puede trabajar',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _workingDays.isEmpty
                      ? 'Sin selección: cualquier día.'
                      : 'Solo: ${(_workingDays.toList()..sort()).map(weekdayShort).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(weekdayShort(day)),
                      selected: _workingDays.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _workingDays.add(day);
                        } else {
                          _workingDays.remove(day);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      );
}

// ---------------------------------------------------------------------------
// Puestos
// ---------------------------------------------------------------------------

class _RolesTab extends StatefulWidget {
  const _RolesTab();
  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  late Future<List<JobRole>> _future = Db.i.roles();

  void _reload() {
    if (mounted) setState(() => _future = Db.i.roles());
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  Future<void> _edit([JobRole? role]) async {
    final result = await showDialog<JobRole>(
      context: context,
      builder: (_) => _RoleDialog(role: role),
    );
    if (result == null) return;
    try {
      if (role == null) {
        await Db.i.addRole(result);
      } else {
        await Db.i.updateRole(result);
      }
    } on StateError catch (e) {
      if (!mounted) return;
      _snack(context, e.message.toString());
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo guardar el puesto: $e');
    }
  }

  Future<void> _delete(JobRole role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar ${role.name}?'),
        content: const Text(
          'Solo se puede borrar si no tiene empleados asignados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Db.i.deleteRole(role.id!);
    } on StateError catch (e) {
      if (!mounted) return;
      _snack(context, e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<JobRole>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los puestos: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final roles = snapshot.data!;
            if (roles.isEmpty) {
              return const Center(
                child: Text('Crea tu primer puesto con +'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: roles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final role = roles[index];
                return ListTile(
                  leading: Icon(_floorIcon(role.floor)),
                  title: Text(role.name),
                  subtitle: Text(
                    '${role.floor.label}'
                    '${role.note.trim().isEmpty ? '' : ' · ${role.note.trim()}'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(role),
                  ),
                  onTap: () => _edit(role),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _edit(),
          child: const Icon(Icons.work_outline),
        ),
      );
}

class _RoleDialog extends StatefulWidget {
  final JobRole? role;
  const _RoleDialog({required this.role});

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.role?.name ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.role?.note ?? '');
  late Floor _floor = widget.role?.floor ?? Floor.plantaBaja;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack(context, 'El nombre del puesto es obligatorio.');
      return;
    }
    Navigator.pop(
      context,
      JobRole(
        id: widget.role?.id,
        name: name,
        floor: _floor,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.role == null ? 'Nuevo puesto' : 'Editar puesto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              DropdownButtonFormField<Floor>(
                initialValue: _floor,
                decoration: const InputDecoration(labelText: 'Planta'),
                items: [
                  for (final floor in Floor.values)
                    DropdownMenuItem(value: floor, child: Text(floor.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _floor = value);
                },
              ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Nota del puesto (opcional)',
                  hintText: 'Evento privado en el karaoke',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      );
}
