import 'models.dart';
import 'schedule.dart';

/// Plantas del local. El puesto de cada empleado pertenece a una sola planta.
enum Floor {
  plantaBaja('planta_baja', 'Planta baja'),
  karaoke('karaoke', 'Karaoke'),
  terraza('terraza', 'Terraza');

  const Floor(this.db, this.label);
  final String db;
  final String label;

  static Floor fromDb(String? value) => values.firstWhere(
        (f) => f.db == value,
        orElse: () => Floor.plantaBaja,
      );
}

/// Estado de un turno. El generador crea borradores; publicar los hace
/// visibles y el empleado puede confirmarlos.
enum ShiftStatus {
  draft('borrador', 'Borrador'),
  published('publicado', 'Publicado'),
  confirmed('confirmado', 'Confirmado');

  const ShiftStatus(this.db, this.label);
  final String db;
  final String label;

  static ShiftStatus fromDb(String? value) => values.firstWhere(
        (s) => s.db == value,
        orElse: () => ShiftStatus.draft,
      );
}

/// Puesto de trabajo configurable. Todos los empleados de un puesto comparten
/// planta y nota (por ejemplo, un evento privado en el karaoke).
class JobRole {
  final int? id;
  final String name;
  final Floor floor;
  final String note;

  const JobRole({
    this.id,
    required this.name,
    this.floor = Floor.plantaBaja,
    this.note = '',
  });

  factory JobRole.fromRow(Map<String, Object?> m) => JobRole(
        id: m['id'] as int,
        name: m['name'] as String,
        floor: Floor.fromDb(m['floor'] as String?),
        note: (m['note'] as String?) ?? '',
      );

  String? get validationError =>
      name.trim().isEmpty ? 'El nombre del puesto es obligatorio.' : null;

  JobRole copyWith({
    int? id,
    String? name,
    Floor? floor,
    String? note,
  }) =>
      JobRole(
        id: id ?? this.id,
        name: name ?? this.name,
        floor: floor ?? this.floor,
        note: note ?? this.note,
      );
}

/// Empleado del local. Cubre un único puesto y solo se le asignan turnos si
/// está activo.
class Employee {
  final int? id;
  final String name;
  final JobRole role;
  final bool active;

  const Employee({
    this.id,
    required this.name,
    required this.role,
    this.active = true,
  });

  factory Employee.fromRow(Map<String, Object?> m) => Employee(
        id: m['id'] as int,
        name: m['name'] as String,
        active: (m['active'] as int) == 1,
        role: JobRole(
          id: m['role_id'] as int,
          name: m['role_name'] as String,
          floor: Floor.fromDb(m['floor'] as String?),
          note: (m['role_note'] as String?) ?? '',
        ),
      );

  String? get validationError =>
      name.trim().isEmpty ? 'El nombre del empleado es obligatorio.' : null;

  Employee copyWith({
    int? id,
    String? name,
    JobRole? role,
    bool? active,
  }) =>
      Employee(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        active: active ?? this.active,
      );
}

/// Turno de una noche. [date] es el día de servicio (`yyyy-MM-dd`): un turno
/// que termina a las 04:00 sigue perteneciendo a la noche anterior.
class Shift {
  final int? id;
  final String date;
  final int employeeId;
  final String employeeName;
  final int roleId;
  final String roleName;
  final Floor floor;
  final int startMin; // minutos desde medianoche
  final int endMin; // si es menor que startMin, termina al día siguiente
  final int breakMin;
  final ShiftStatus status;
  final String note;

  const Shift({
    this.id,
    required this.date,
    required this.employeeId,
    required this.employeeName,
    required this.roleId,
    required this.roleName,
    required this.floor,
    required this.startMin,
    required this.endMin,
    required this.breakMin,
    this.status = ShiftStatus.draft,
    this.note = '',
  });

  factory Shift.fromRow(Map<String, Object?> m) => Shift(
        id: m['id'] as int,
        date: m['date'] as String,
        employeeId: m['employee_id'] as int,
        employeeName: m['employee_name'] as String,
        roleId: m['role_id'] as int,
        roleName: m['role_name'] as String,
        floor: Floor.fromDb(m['floor'] as String?),
        startMin: m['start_min'] as int,
        endMin: m['end_min'] as int,
        breakMin: m['break_min'] as int,
        status: ShiftStatus.fromDb(m['status'] as String?),
        note: (m['note'] as String?) ?? '',
      );

  int get durationMinutes => shiftDurationMinutes(startMin, endMin);
  int get workedMinutes => durationMinutes - breakMin;
  bool get crossesMidnight => endMin < startMin;
  String get timeLabel => '${formatMinutes(startMin)}–${formatMinutes(endMin)}';
  String get hoursLabel => formatHours(workedMinutes);

  Shift copyWith({
    int? id,
    int? startMin,
    int? endMin,
    int? breakMin,
    ShiftStatus? status,
    String? note,
  }) =>
      Shift(
        id: id ?? this.id,
        date: date,
        employeeId: employeeId,
        employeeName: employeeName,
        roleId: roleId,
        roleName: roleName,
        floor: floor,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
        breakMin: breakMin ?? this.breakMin,
        status: status ?? this.status,
        note: note ?? this.note,
      );
}

/// Duración en minutos. Si la salida es anterior a la entrada, cruza medianoche.
int shiftDurationMinutes(int startMin, int endMin) {
  if (startMin == endMin) return 0;
  final raw = endMin - startMin;
  return raw > 0 ? raw : raw + 24 * 60;
}

/// Descanso automático según la regla del local:
/// - solo para quien entra antes de las 21:00;
/// - más de 8 h → 40 min;
/// - más de 6 h → 25 min.
int breakMinutesFor({required int startMin, required int endMin}) {
  if (startMin >= Schedule.peakHour * 60) return 0;
  final duration = shiftDurationMinutes(startMin, endMin);
  if (duration > 8 * 60) return 40;
  if (duration > 6 * 60) return 25;
  return 0;
}

/// Minutos efectivamente trabajados, descontando el descanso.
int workedMinutesFor({required int startMin, required int endMin}) =>
    shiftDurationMinutes(startMin, endMin) -
    breakMinutesFor(startMin: startMin, endMin: endMin);

String formatMinutes(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

String formatHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Genera el horario de un mes a partir de los empleados activos.
///
/// Solo se trabaja viernes y sábado. Cada empleado hace un turno por noche:
/// apertura (16:00–21:00) o segundo turno (21:00–04:00). Para equilibrar las
/// horas, dentro de cada planta se asignan los turnos más largos a quienes
/// llevan menos horas acumuladas en el mes. Si una planta tiene una sola
/// persona, esa persona cubre el turno completo (16:00–04:00) para no dejar la
/// planta sin nadie.
///
/// Las excepciones de cierre (`SpecialDay.open == false`) se respetan; las
/// aperturas extra no se generan automáticamente.
class ShiftGenerator {
  static const int openingStart = Schedule.openHour * 60; // 16:00
  static const int openingEnd = Schedule.peakHour * 60; // 21:00
  static const int closingEnd = Schedule.closeHour * 60; // 04:00

  static List<Shift> generateMonth({
    required DateTime month,
    required List<Employee> employees,
    required Map<String, SpecialDay> specialDays,
  }) {
    final active = [
      for (final e in employees)
        if (e.active && e.id != null && e.role.id != null) e,
    ];
    if (active.isEmpty) return const [];

    final byFloor = <Floor, List<Employee>>{};
    for (final e in active) {
      byFloor.putIfAbsent(e.role.floor, () => []).add(e);
    }

    // Horas acumuladas en el mes por empleado, para repartir los turnos largos.
    final worked = <int, int>{for (final e in active) e.id!: 0};
    final out = <Shift>[];

    // Se recorre por componentes (no con Duration(days: 1)) para no perder el
    // último día cuando cambia la hora oficial.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(month.year, month.month, day);
      if (!Schedule.openWeekdays.contains(d.weekday)) continue;
      final key = Schedule.fmt(d);
      final special = specialDays[key];
      if (special != null && !special.open) continue;

      for (final floor in Floor.values) {
        final group = byFloor[floor];
        if (group == null || group.isEmpty) continue;

        // Menos horas primero: así los turnos largos rotan.
        group.sort((a, b) {
          final byHours = worked[a.id]!.compareTo(worked[b.id]!);
          return byHours != 0 ? byHours : a.name.compareTo(b.name);
        });

        if (group.length == 1) {
          final e = group.single;
          out.add(_build(d, e, openingStart, closingEnd));
          final minutes =
              workedMinutesFor(startMin: openingStart, endMin: closingEnd);
          worked[e.id!] = worked[e.id!]! + minutes;
          continue;
        }

        // La mitad (redondeando hacia arriba) hace el turno largo de 7 h. Así
        // siempre hay al menos una persona en apertura y otra en el segundo.
        final lateCount = (group.length / 2).ceil();
        for (var i = 0; i < group.length; i++) {
          final e = group[i];
          final late = i < lateCount;
          final start = late ? openingEnd : openingStart;
          final end = late ? closingEnd : openingEnd;
          out.add(_build(d, e, start, end));
          worked[e.id!] =
              worked[e.id!]! + workedMinutesFor(startMin: start, endMin: end);
        }
      }
    }

    out.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byFloor = a.floor.index.compareTo(b.floor.index);
      return byFloor != 0 ? byFloor : a.employeeName.compareTo(b.employeeName);
    });
    return out;
  }

  static Shift _build(DateTime date, Employee e, int start, int end) => Shift(
        date: Schedule.fmt(date),
        employeeId: e.id!,
        employeeName: e.name,
        roleId: e.role.id!,
        roleName: e.role.name,
        floor: e.role.floor,
        startMin: start,
        endMin: end,
        breakMin: breakMinutesFor(startMin: start, endMin: end),
        status: ShiftStatus.draft,
        note: e.role.note.trim(),
      );
}
