import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../shifts.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _dateLabel(String date) =>
    _cap(DateFormat('EEEE d MMMM', 'es').format(DateTime.parse(date)));

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
  _ScheduleData(this.shifts, this.employees);
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();
  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<_ScheduleData> _future = _load();

  Future<_ScheduleData> _load() async {
    final shifts = await Db.i.shiftsForMonth(_month);
    final employees = await Db.i.employees();
    return _ScheduleData(shifts, employees);
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
        _future = _load();
      });

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

    final special = await Db.i.specialDays();
    final generated = ShiftGenerator.generateMonth(
      month: _month,
      employees: data.employees,
      specialDays: special,
    );
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
          final days = <String, List<Shift>>{};
          for (final shift in data.shifts) {
            days.putIfAbsent(shift.date, () => []).add(shift);
          }
          final sortedDays = days.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

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
              if (data.shifts.isNotEmpty) _hoursSummary(data),
              const SizedBox(height: 12),
              if (data.shifts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No hay turnos este mes. Pulsa «Generar mes» para '
                      'crearlos a partir de los empleados.',
                    ),
                  ),
                )
              else
                for (final day in sortedDays)
                  _DayCard(
                    date: day.key,
                    shifts: day.value,
                    onEdit: _editShift,
                    onDelete: _deleteShift,
                  ),
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
                    '${employee.role.name} · ${employee.role.floor.label}',
                  ),
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
