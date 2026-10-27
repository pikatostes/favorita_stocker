import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth.dart';
import '../auth_controller.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
import '../shifts.dart';
import '../widgets/app_logo.dart';
import '../widgets/month_calendar.dart';

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

/// Pestañas internas de Turnos. [roles] (Puestos) solo está disponible para
/// administradores.
enum TurnoTab {
  schedule('Horario'),
  users('Usuarios'),
  roles('Puestos', adminOnly: true);

  final String label;
  final bool adminOnly;

  const TurnoTab(this.label, {this.adminOnly = false});
}

/// Pestañas internas de Turnos visibles para [role].
List<TurnoTab> visibleTurnoTabs(UserRole role) => [
      for (final tab in TurnoTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];

/// Pestaña "Turnos": horario mensual, usuarios y puestos.
class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});
  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen>
    with TickerProviderStateMixin {
  late bool _isAdmin;
  late TabController _tabs;

  bool get _hasAdminRole => AuthController.i.user?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _isAdmin = _hasAdminRole;
    _tabs = TabController(length: _isAdmin ? 3 : 2, vsync: this);
    AuthController.i.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthController.i.removeListener(_onAuthChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final isAdmin = _hasAdminRole;
    if (isAdmin == _isAdmin) return;

    final old = _tabs;
    final length = isAdmin ? 3 : 2;
    final nextIndex = old.index >= length ? 0 : old.index;
    setState(() {
      _isAdmin = isAdmin;
      _tabs = TabController(
        length: length,
        vsync: this,
        initialIndex: nextIndex,
      );
    });
    old.dispose();
  }

  Widget _pageFor(TurnoTab tab) => switch (tab) {
        TurnoTab.schedule => _ScheduleTab(isAdmin: _isAdmin),
        TurnoTab.users => _AppUsersTab(isAdmin: _isAdmin),
        TurnoTab.roles => const _RolesTab(),
      };

  @override
  Widget build(BuildContext context) {
    final tabs = visibleTurnoTabs(
      AuthController.i.user?.role ?? UserRole.employee,
    );
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final tab in tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [for (final tab in tabs) _pageFor(tab)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horario
// ---------------------------------------------------------------------------

class _ScheduleData {
  final List<Shift> shifts;
  final List<AppUser> users;
  final Map<String, SpecialDay> special;
  _ScheduleData(this.shifts, this.users, this.special);
}

class _ScheduleTab extends StatefulWidget {
  final bool isAdmin;

  const _ScheduleTab({required this.isAdmin});

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
    final usersF = Db.i.users();
    final specialF = Db.i.specialDays();
    final users =
        (await usersF).where((u) => u.jobRole != null).toList(growable: false);
    return _ScheduleData(await shiftsF, users, await specialF);
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
    if (data.users.isEmpty) {
      _snack(context,
          'Añade al menos un usuario en la pestaña «Usuarios» para generar.');
      return;
    }

    if (data.shifts.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerar el mes'),
          content: Text(
              'Se borrarán los ${data.shifts.length} turnos de este mes y se '
              'crearán de nuevo a partir de los usuarios.'),
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
      users: data.users,
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
        title: Text('¿Borrar el turno de ${shift.userName}?'),
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

  CalendarDayStyle _dayStyle(
    _ScheduleData data,
    Map<String, List<Shift>> byDate,
    DateTime day,
  ) {
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final special = data.special[key];
    if ((byDate[key] ?? const <Shift>[]).isNotEmpty) {
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

  Widget? _dayFooter(
    _ScheduleData data,
    Map<String, List<Shift>> byDate,
    DateTime day,
  ) {
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final shifts = byDate[key] ?? const <Shift>[];
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
              MonthCalendar(
                month: _month,
                selected: _selected,
                onSelect: (day) => setState(() => _selected = day),
                onMonthChanged: (month) => setState(() {
                  _month = month;
                  _selected = _firstOpenDay(month);
                  _future = _load();
                }),
                styleFor: (day) => _dayStyle(data, byDate, day),
                footerFor: (day) => _dayFooter(data, byDate, day),
                cellHeight: 50,
                headerActions: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.isAdmin) ...[
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
                    TextButton.icon(
                      onPressed: _goToday,
                      icon: const Icon(Icons.today),
                      label: const Text('Hoy'),
                    ),
                  ],
                ),
              ),
              if (data.users.isEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.isAdmin
                          ? 'Añade puestos en «Puestos» y usuarios en '
                              '«Usuarios» para poder generar el horario.'
                          : 'Todavía no hay usuarios con un puesto asignado.',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _legend(),
              const SizedBox(height: 8),
              _dayDetails(data, byDate),
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
                            _ShiftTimeline(
                              shifts: floorShifts,
                              onEdit: onEdit,
                              onDelete: onDelete,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toca un avatar para editar · mantén pulsado '
                              'para borrar',
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

/// Línea temporal de los turnos de una planta.
///
/// Cada fila agrupa a las personas que comparten el mismo horario. La barra
/// empieza en la hora de entrada y termina en la de salida (ambas rotuladas) y
/// los avatares van dentro. No se dibuja el eje con todas las horas ni hay
/// desplazamiento horizontal: si los avatares no caben en la barra, se reparten
/// en varias líneas y la fila crece en vertical.
class _ShiftTimeline extends StatelessWidget {
  final List<Shift> shifts;
  final ValueChanged<Shift> onEdit;
  final ValueChanged<Shift> onDelete;

  const _ShiftTimeline({
    required this.shifts,
    required this.onEdit,
    required this.onDelete,
  });

  /// Escala de la noche: de las 16:00 a las 04:00 del día siguiente.
  static const int _axisStart = Schedule.openHour * 60;
  static const int _axisEnd = 28 * 60;
  static const int _totalMinutes = _axisEnd - _axisStart;

  static const double _avatarSize = 30;
  static const double _avatarGap = 4;
  static const double _barMinHeight = 36;
  static const double _barPadding = 4;
  static const double _labelHeight = 16;
  static const double _labelGap = 2;
  static const double _rowGap = 10;

  /// Minutos del eje: lo anterior a las 16:00 pertenece a la madrugada.
  int _axisMinute(int minutes) =>
      minutes < _axisStart ? minutes + 24 * 60 : minutes;

  @override
  Widget build(BuildContext context) {
    final groups = <(int, int), List<Shift>>{};
    for (final shift in shifts) {
      groups.putIfAbsent((shift.startMin, shift.endMin), () => []).add(shift);
    }
    final rows = groups.entries.toList()
      ..sort((a, b) {
        final byStart = _axisMinute(a.key.$1) - _axisMinute(b.key.$1);
        return byStart != 0 ? byStart : a.key.$2 - b.key.$2;
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        double xOf(int minutes) {
          final m = math.min(
            _axisEnd,
            math.max(_axisStart, _axisMinute(minutes)),
          );
          return (m - _axisStart) / _totalMinutes * width;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              _timelineRow(
                context,
                row.key,
                row.value,
                width: width,
                xOf: xOf,
              ),
          ],
        );
      },
    );
  }

  Widget _timelineRow(
    BuildContext context,
    (int, int) range,
    List<Shift> rowShifts, {
    required double width,
    required double Function(int) xOf,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final start = range.$1;
    final end = range.$2;
    final sorted = [...rowShifts]..sort(
        (a, b) => a.userName.toLowerCase().compareTo(
              b.userName.toLowerCase(),
            ),
      );

    // La barra necesita un mínimo para que quepa al menos un avatar.
    const minBarWidth = _avatarSize + _barPadding * 2;
    var barLeft = xOf(start);
    var barRight = xOf(end);
    if (barRight - barLeft < minBarWidth) {
      barRight = barLeft + minBarWidth;
      if (barRight > width) {
        barRight = width;
        barLeft = math.max(0, width - minBarWidth);
      }
    }
    final barWidth = barRight - barLeft;

    // Si los avatares no caben a lo ancho, se reparten en varias líneas y la
    // fila crece en vertical (nunca se desplaza horizontalmente).
    final innerWidth = barWidth - _barPadding * 2;
    final perLine = math.max(
      1,
      ((innerWidth + _avatarGap) / (_avatarSize + _avatarGap)).floor(),
    );
    final lines = (sorted.length / perLine).ceil();
    final avatarsHeight = lines * _avatarSize + (lines - 1) * _avatarGap;
    final barHeight = math.max(
      _barMinHeight,
      avatarsHeight + _barPadding * 2,
    );
    final rowHeight = _labelHeight + _labelGap + barHeight + _rowGap;

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final separateLabels = barWidth >= 96;

    return SizedBox(
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (separateLabels) ...[
            Positioned(
              left: barLeft,
              top: 0,
              child: Text(formatMinutes(start), style: labelStyle),
            ),
            Positioned(
              right: width - barRight,
              top: 0,
              child: Text(formatMinutes(end), style: labelStyle),
            ),
          ] else
            Positioned(
              left: barLeft,
              width: barWidth,
              top: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatMinutes(start)}–${formatMinutes(end)}',
                  style: labelStyle,
                ),
              ),
            ),
          Positioned(
            left: barLeft,
            top: _labelHeight + _labelGap,
            width: barWidth,
            height: barHeight,
            child: Container(
              padding: const EdgeInsets.all(_barPadding),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: _avatarGap,
                  runSpacing: _avatarGap,
                  children: [
                    for (final shift in sorted)
                      _TimelineAvatar(
                        shift: shift,
                        onTap: () => onEdit(shift),
                        onLongPress: () => onDelete(shift),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar con la inicial y un punto de color según el estado del turno.
/// Tocar edita; mantener pulsado borra (con confirmación).
class _TimelineAvatar extends StatelessWidget {
  final Shift shift;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineAvatar({
    required this.shift,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = shift.userName.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final statusColor = switch (shift.status) {
      ShiftStatus.draft => cs.outline,
      ShiftStatus.published => cs.primary,
      ShiftStatus.confirmed => cs.tertiary,
    };

    return Semantics(
      button: true,
      label: '${name.isEmpty ? 'Sin nombre' : name}, '
          '${shift.timeLabel}, ${shift.status.label}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: _ShiftTimeline._avatarSize,
          height: _ShiftTimeline._avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: _ShiftTimeline._avatarSize / 2,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
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
        userId: widget.shift.userId,
        userName: widget.shift.userName,
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
              '${widget.shift.userName} · ${widget.shift.roleName}',
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
// Usuarios
// ---------------------------------------------------------------------------

class _AppUsersTab extends StatefulWidget {
  final bool isAdmin;

  const _AppUsersTab({required this.isAdmin});

  @override
  State<_AppUsersTab> createState() => _AppUsersTabState();
}

class _AppUsersTabState extends State<_AppUsersTab> {
  late Future<List<AppUser>> _future = Db.i.users(includeInactive: true);

  void _reload() {
    if (mounted) {
      setState(() => _future = Db.i.users(includeInactive: true));
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

  Future<void> _edit([AppUser? user]) async {
    if (!widget.isAdmin) return;
    final roles = await Db.i.roles();
    if (!mounted) return;
    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (_) => _AppUserDialog(user: user, roles: roles),
    );
    if (result == null) return;
    try {
      if (user == null) {
        await Db.i.addUser(result.user, password: result.password!);
      } else {
        await Db.i.updateUser(result.user, password: result.password);
        await AuthController.i.refresh();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo guardar el usuario: $e');
    }
  }

  Future<void> _toggle(AppUser user) async {
    if (!widget.isAdmin) return;
    try {
      await Db.i.setUserActive(user.id!, !user.active);
      await AuthController.i.refresh();
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'No se pudo cambiar el estado: $e');
    }
  }

  Future<void> _showInfo(AppUser user) => showDialog<void>(
        context: context,
        builder: (_) => _UserInfoDialog(user: user),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<AppUser>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los usuarios: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!;
            if (users.isEmpty) {
              return Center(
                child: Text(
                  widget.isAdmin
                      ? 'Añade tu primer usuario con +'
                      : 'No hay usuarios.',
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final jobRole = user.jobRole;
                return ListTile(
                  leading: CircleAvatar(child: Text(user.initial)),
                  title: Text(
                    user.fullName,
                    style: user.active
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.lineThrough),
                  ),
                  subtitle: Text(
                    '${user.email}\n'
                    '${user.role.label}'
                    ' · ${jobRole == null ? 'Sin puesto' : '${jobRole.name} · ${jobRole.floor.label}'}'
                    ' · ${user.workingDaysLabel}'
                    '${user.opener ? ' · Puede abrir' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: widget.isAdmin
                      ? Switch(
                          value: user.active,
                          onChanged: (_) => _toggle(user),
                        )
                      : null,
                  onTap: () => widget.isAdmin ? _edit(user) : _showInfo(user),
                );
              },
            );
          },
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton(
                onPressed: () => _edit(),
                child: const Icon(Icons.person_add),
              )
            : null,
      );
}

/// Ficha de solo lectura que se muestra a los empleados al tocar un usuario.
class _UserInfoDialog extends StatelessWidget {
  final AppUser user;

  const _UserInfoDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    final jobRole = user.jobRole;
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(child: Text(user.initial)),
          const SizedBox(width: 12),
          Expanded(child: Text(user.fullName)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'Email',
              value: user.email.isEmpty ? 'Sin email' : user.email,
            ),
            _InfoRow(
              icon: Icons.shield_outlined,
              label: 'Rol de acceso',
              value: user.role.label,
            ),
            _InfoRow(
              icon: Icons.work_outline,
              label: 'Puesto habitual',
              value: jobRole == null
                  ? 'Sin puesto'
                  : '${jobRole.name} · ${jobRole.floor.label}',
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Estado',
              value: user.active ? 'Activo' : 'Inactivo',
            ),
            _InfoRow(
              icon: Icons.lock_open_outlined,
              label: 'Puede abrir',
              value: user.opener ? 'Sí' : 'No',
            ),
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: 'Días que puede trabajar',
              value: user.workingDaysLabel,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      );
}

class _AppUserDialog extends StatefulWidget {
  final AppUser? user;
  final List<JobRole> roles;

  const _AppUserDialog({required this.user, required this.roles});

  @override
  State<_AppUserDialog> createState() => _AppUserDialogState();
}

class _UserFormResult {
  final AppUser user;
  final String? password;

  const _UserFormResult({required this.user, this.password});
}

class _AppUserDialogState extends State<_AppUserDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _surname =
      TextEditingController(text: widget.user?.surname ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();
  JobRole? _jobRole;
  late UserRole _accessRole = widget.user?.role ?? UserRole.employee;
  late bool _active = widget.user?.active ?? true;
  late bool _opener = widget.user?.opener ?? false;
  late final Set<int> _workingDays = {...?widget.user?.workingDays};
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // El usuario trae una instancia de JobRole distinta a la de la lista de
    // puestos. El DropdownButton compara por identidad, así que hay que usar
    // exactamente el objeto que aparece en sus items.
    _jobRole = roleFromList(widget.roles, widget.user?.jobRole);
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final password = _password.text;
    Navigator.pop(
      context,
      _UserFormResult(
        user: AppUser(
          id: widget.user?.id,
          name: _name.text.trim(),
          surname: _surname.text.trim(),
          email: _email.text.trim().toLowerCase(),
          jobRole: _jobRole,
          role: _accessRole,
          active: _active,
          opener: _opener,
          workingDays: _workingDays,
        ),
        password: password.isEmpty ? null : password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    final canAssignRole = AuthController.i.user?.role == UserRole.admin;
    return AlertDialog(
      title: Text(editing ? 'Editar usuario' : 'Nuevo usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
              TextFormField(
                controller: _surname,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    isValidEmail(value ?? '') ? null : 'El email no es válido.',
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: editing ? 'Nueva contraseña' : 'Contraseña',
                  helperText: editing
                      ? 'Déjala vacía para mantener la actual.'
                      : 'Mínimo 6 caracteres.',
                  suffixIcon: IconButton(
                    tooltip:
                        _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (!editing && password.isEmpty) {
                    return 'La contraseña es obligatoria.';
                  }
                  if (password.isNotEmpty && password.length < 6) {
                    return 'Debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              if (canAssignRole)
                DropdownButtonFormField<UserRole>(
                  initialValue: _accessRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rol de acceso'),
                  items: [
                    for (final role in UserRole.values)
                      DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _accessRole = value ?? UserRole.employee,
                  ),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rol de acceso'),
                  subtitle: Text(_accessRole.label),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
              DropdownButtonFormField<JobRole>(
                initialValue: _jobRole,
                isExpanded: true,
                hint: const Text('Sin puesto'),
                decoration: const InputDecoration(labelText: 'Puesto habitual'),
                items: [
                  for (final role in widget.roles)
                    DropdownMenuItem<JobRole>(
                      value: role,
                      child: Text(
                        '${role.name} · ${role.floor.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _jobRole = value),
              ),
              if (_jobRole != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _jobRole = null),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Dejar sin puesto'),
                  ),
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
          'Solo se puede borrar si no tiene usuarios asignados.',
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
