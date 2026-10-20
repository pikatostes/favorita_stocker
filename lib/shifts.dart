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

/// Usuario del local. Cubre un único puesto (puede no tenerlo todavía, por
/// ejemplo al registrarse) y solo se le asignan turnos si está activo.
class AppUser {
  final int? id;
  final String name;
  final String surname;
  final String email;
  final JobRole? role;
  final bool active;

  /// Capacidad de abrir el bar o su planta.
  final bool opener;

  /// Días de la semana en que puede trabajar habitualmente (1 = lunes,
  /// 7 = domingo). El conjunto vacío significa "cualquier día". Solo se usa
  /// para generar el horario automático.
  final Set<int> workingDays;

  const AppUser({
    this.id,
    required this.name,
    this.surname = '',
    this.email = '',
    this.role,
    this.active = true,
    this.opener = false,
    this.workingDays = const {},
  });

  factory AppUser.fromRow(Map<String, Object?> m) {
    final roleId = m['role_id'] as int?;
    return AppUser(
      id: m['id'] as int,
      name: m['name'] as String,
      surname: (m['surname'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      active: (m['active'] as int) == 1,
      opener: (m['opener'] as int?) == 1,
      workingDays: parseWorkingDays(m['working_days']),
      role: roleId == null
          ? null
          : JobRole(
              id: roleId,
              name: m['role_name'] as String,
              floor: Floor.fromDb(m['floor'] as String?),
              note: (m['role_note'] as String?) ?? '',
            ),
    );
  }

  /// Nombre completo para mostrar en listas y turnos.
  String get fullName =>
      [name.trim(), surname.trim()].where((p) => p.isNotEmpty).join(' ');

  /// Inicial para el avatar de la lista.
  String get initial =>
      fullName.isEmpty ? '?' : fullName.substring(0, 1).toUpperCase();

  /// Días de la semana (1 = lunes .. 7 = domingo) guardados como "5,6".
  /// Un valor vacío o nulo significa "cualquier día".
  static Set<int> parseWorkingDays(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const {};
    final days = <int>{};
    for (final part in raw.split(',')) {
      final n = int.tryParse(part.trim());
      if (n != null && n >= DateTime.monday && n <= DateTime.sunday) {
        days.add(n);
      }
    }
    return days;
  }

  /// Serializa los días a texto ("5,6"); vacío si no hay restricción.
  static String formatWorkingDays(Set<int> days) {
    final sorted = days
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toList()
      ..sort();
    return sorted.join(',');
  }

  /// Etiqueta legible: "Vie, Sáb" o "Cualquier día" si no hay restricción.
  String get workingDaysLabel => workingDays.isEmpty
      ? 'Cualquier día'
      : (workingDays.toList()..sort()).map(weekdayShort).join(', ');

  String? get validationError {
    if (name.trim().isEmpty) return 'El nombre del usuario es obligatorio.';
    if (email.trim().isNotEmpty && !email.contains('@')) {
      return 'El email no es válido.';
    }
    return null;
  }

  AppUser copyWith({
    int? id,
    String? name,
    String? surname,
    String? email,
    JobRole? role,
    bool clearRole = false,
    bool? active,
    bool? opener,
    Set<int>? workingDays,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        surname: surname ?? this.surname,
        email: email ?? this.email,
        role: clearRole ? null : (role ?? this.role),
        active: active ?? this.active,
        opener: opener ?? this.opener,
        workingDays: workingDays ?? this.workingDays,
      );
}

/// Turno de una noche. [date] es el día de servicio (`yyyy-MM-dd`): un turno
/// que termina a las 04:00 sigue perteneciendo a la noche anterior.
class Shift {
  final int? id;
  final String date;
  final int userId;
  final String userName;
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
    required this.userId,
    required this.userName,
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
        userId: m['user_id'] as int,
        userName: m['user_name'] as String,
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
        userId: userId,
        userName: userName,
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

/// Nombre corto del día de la semana (1 = lunes .. 7 = domingo).
const List<String> weekdayShortNames = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

String weekdayShort(int weekday) => weekdayShortNames[weekday - 1];

/// Genera el horario de un mes a partir de los empleados activos.
///
/// Solo se trabaja viernes y sábado. Cada empleado hace un turno por noche:
/// apertura (16:00–21:00), segundo turno (21:00–04:00) o turno completo
/// (16:00–04:00) cuando hace falta cubrir ambos tramos. Para equilibrar las
/// horas, dentro de cada planta se asignan los turnos más largos a quienes
/// llevan menos horas acumuladas en el mes.
///
/// La terraza abre a las 21:00 los viernes y a las 16:00 los sábados; en ambos
/// casos necesita al menos dos personas desde la hora de apertura. Si no hay
/// suficientes empleados disponibles, se programa a todos y la terraza queda
/// incompleta.
///
/// Las excepciones de cierre (`SpecialDay.open == false`) se respetan; las
/// aperturas extra no se generan automáticamente. Un usuario solo entra en un
/// día si no tiene restricción de [AppUser.workingDays] o si ese día está
/// entre sus días. La apertura solo la cubre quien tiene [AppUser.opener]; si
/// una planta no tiene ningún opener disponible esa noche, no se programa.
class ShiftGenerator {
  static const int openingStart = Schedule.openHour * 60; // 16:00
  static const int openingEnd = Schedule.peakHour * 60; // 21:00
  static const int closingEnd = Schedule.closeHour * 60; // 04:00

  static List<Shift> generateMonth({
    required DateTime month,
    required List<AppUser> users,
    required Map<String, SpecialDay> specialDays,
  }) {
    final active = [
      for (final e in users)
        if (e.active && e.id != null && e.role?.id != null) e,
    ];
    if (active.isEmpty) return const [];

    final byFloor = <Floor, List<AppUser>>{};
    for (final e in active) {
      byFloor.putIfAbsent(e.role!.floor, () => []).add(e);
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

        // Solo quien puede trabajar ese día de la semana. Los empleados sin
        // restricción ([workingDays] vacío) valen cualquier día.
        final available = [
          for (final e in group)
            if (e.workingDays.isEmpty || e.workingDays.contains(d.weekday)) e,
        ];
        if (available.isEmpty) continue;

        // La apertura solo la puede cubrir quien tiene `opener = true`. Si esa
        // noche no hay ningún opener disponible, la planta no se abre y no se
        // genera nada para ella (el hueco queda visible en el calendario).
        final openers = [for (final e in available) if (e.opener) e];
        if (openers.isEmpty) continue;

        // Los viernes la terraza abre a las 21:00: no hay turno a las 16:00 y
        // todo el mundo empieza en el segundo turno. Al haber un opener
        // disponible, la terraza se puede abrir.
        if (floor == Floor.terraza && d.weekday == DateTime.friday) {
          for (final e in available) {
            out.add(_build(d, e, openingEnd, closingEnd));
            worked[e.id!] = worked[e.id!]! +
                workedMinutesFor(startMin: openingEnd, endMin: closingEnd);
          }
          continue;
        }

        // Mínimos de personas por tramo según la planta y el día.
        final mins = _minimums(floor, d.weekday);
        final counts = _splitCounts(
          n: available.length,
          openers: openers.length,
          openMin: mins.open,
          peakMin: mins.peak,
        );

        // Los turnos completos (los más largos) van a los openers con menos
        // horas del mes; la apertura (el más corto), a los que llevan más. Así
        // los turnos largos rotan. Los no-openers van al segundo turno.
        final openersByHours = openers.toList()
          ..sort((a, b) {
            final byHours = worked[a.id]!.compareTo(worked[b.id]!);
            return byHours != 0 ? byHours : a.name.compareTo(b.name);
          });
        final fullIds =
            openersByHours.take(counts.full).map((e) => e.id).toSet();
        final earlyIds = (openersByHours.skip(counts.full).toList()
              ..sort((a, b) {
                final byHours = worked[b.id]!.compareTo(worked[a.id]!);
                return byHours != 0 ? byHours : a.name.compareTo(b.name);
              }))
            .take(counts.early)
            .map((e) => e.id)
            .toSet();

        for (final e in available) {
          final int start;
          final int end;
          if (fullIds.contains(e.id)) {
            start = openingStart;
            end = closingEnd;
          } else if (earlyIds.contains(e.id)) {
            start = openingStart;
            end = openingEnd;
          } else {
            start = openingEnd;
            end = closingEnd;
          }
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
      return byFloor != 0 ? byFloor : a.userName.compareTo(b.userName);
    });
    return out;
  }

  /// Mínimos de personas por tramo (apertura 16:00–21:00 y segundo turno
  /// 21:00–04:00) para una planta y un día. La terraza abre a las 16:00 los
  /// sábados y necesita dos personas desde esa hora; el resto de plantas, una
  /// persona en cada tramo. Los viernes la terraza se trata aparte porque abre
  /// directamente a las 21:00.
  static ({int open, int peak}) _minimums(Floor floor, int weekday) {
    if (floor == Floor.terraza && weekday == DateTime.saturday) {
      return (open: 2, peak: 2);
    }
    return (open: 1, peak: 1);
  }

  /// Reparte [n] personas en apertura, segundo turno y turno completo para
  /// cubrir [openMin] y [peakMin]. El turno completo cuenta para ambos tramos.
  /// Si no se pueden cumplir (p. ej. faltan openers), devuelve el reparto que
  /// cubre lo máximo posible con las personas disponibles.
  static ({int early, int late, int full}) _splitCounts({
    required int n,
    required int openers,
    required int openMin,
    required int peakMin,
  }) {
    if (n <= 1) return (early: 0, late: 0, full: n);

    // Reparto de referencia: mitad en apertura y mitad en el segundo turno.
    final baseEarly = n ~/ 2;
    ({int early, int late, int full})? best;
    int? bestMet;
    int? bestDeficit;
    int? bestDistance;

    for (var full = 0; full <= n; full++) {
      for (var early = 0; early <= n - full; early++) {
        final late = n - full - early;
        if (early + full > openers) continue; // abrir exige opener
        final open = early + full;
        final peak = late + full;
        final met = (open >= openMin ? 1 : 0) + (peak >= peakMin ? 1 : 0);
        final deficit = (openMin > open ? openMin - open : 0) +
            (peakMin > peak ? peakMin - peak : 0);
        // A igualdad de cobertura, parecerse al reparto de referencia y usar
        // los menos turnos completos posibles.
        final distance = (early - baseEarly).abs() * 2 + full;

        final better = best == null ||
            met > bestMet! ||
            (met == bestMet && deficit < bestDeficit!) ||
            (met == bestMet &&
                deficit == bestDeficit &&
                distance < bestDistance!);
        if (better) {
          best = (early: early, late: late, full: full);
          bestMet = met;
          bestDeficit = deficit;
          bestDistance = distance;
        }
      }
    }
    return best!;
  }

  static Shift _build(DateTime date, AppUser e, int start, int end) => Shift(
        date: Schedule.fmt(date),
        userId: e.id!,
        userName: e.fullName,
        roleId: e.role!.id!,
        roleName: e.role!.name,
        floor: e.role!.floor,
        startMin: start,
        endMin: end,
        breakMin: breakMinutesFor(startMin: start, endMin: end),
        status: ShiftStatus.draft,
        note: e.role!.note.trim(),
      );
}
