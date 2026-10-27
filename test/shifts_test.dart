import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/shifts.dart';

JobRole _role(int id, String name, Floor floor, {String note = ''}) =>
    JobRole(id: id, name: name, floor: floor, note: note);

AppUser _user(int id, String name, JobRole jobRole,
        {bool active = true,
        bool opener = false,
        Set<int> workingDays = const {},
        UserRole role = UserRole.employee}) =>
    AppUser(
      id: id,
      name: name,
      jobRole: jobRole,
      role: role,
      active: active,
      opener: opener,
      workingDays: workingDays,
    );

List<Shift> _day(List<Shift> shifts, String date) =>
    shifts.where((s) => s.date == date).toList();

Set<String> _datesOn(List<Shift> shifts, int weekday) => shifts
    .map((s) => s.date)
    .where((d) => DateTime.parse(d).weekday == weekday)
    .toSet();

/// Presentes a las 16:00: apertura y turno completo.
int _atOpening(List<Shift> day) =>
    day.where((s) => s.startMin == ShiftGenerator.openingStart).length;

/// Presentes a las 21:00: segundo turno y turno completo.
int _atPeak(List<Shift> day) =>
    day.where((s) => s.endMin == ShiftGenerator.closingEnd).length;

void main() {
  group('puesto de mantenimiento', () {
    test('reconoce «manteni» y «mantenimiento» sin importar el formato', () {
      bool maintenance(String role) => _user(
            1,
            'Ana',
            _role(1, role, Floor.plantaBaja),
          ).isMaintenance;

      expect(maintenance('manteni'), isTrue);
      expect(maintenance('Mantenimiento'), isTrue);
      expect(maintenance('  MANTENI  '), isTrue);
      expect(maintenance('camarero'), isFalse);
      expect(const AppUser(name: 'Ana').isMaintenance, isFalse);
    });
  });

  group('duración y descansos', () {
    test('calcula la duración y el cruce de medianoche', () {
      expect(shiftDurationMinutes(16 * 60, 21 * 60), 300);
      expect(shiftDurationMinutes(21 * 60, 4 * 60), 420);
      expect(shiftDurationMinutes(16 * 60, 4 * 60), 720);
      expect(shiftDurationMinutes(16 * 60, 16 * 60), 0);
    });

    test('aplica los descansos solo si se entra antes de las 21:00', () {
      // Más de 8 h.
      expect(breakMinutesFor(startMin: 16 * 60, endMin: 4 * 60), 40);
      // Más de 6 h y hasta 8 h.
      expect(breakMinutesFor(startMin: 16 * 60, endMin: 0), 25);
      expect(breakMinutesFor(startMin: 16 * 60, endMin: 22 * 60), 0);
      // Entra a las 21:00 o después: sin descanso aunque dure 7 h.
      expect(breakMinutesFor(startMin: 21 * 60, endMin: 4 * 60), 0);
      // Entra antes de las 21:00 y trabaja 8 h: 25 min.
      expect(breakMinutesFor(startMin: 20 * 60, endMin: 4 * 60), 25);
    });

    test('descuenta el descanso de las horas trabajadas', () {
      expect(workedMinutesFor(startMin: 16 * 60, endMin: 4 * 60), 680);
      expect(workedMinutesFor(startMin: 16 * 60, endMin: 21 * 60), 300);
      expect(workedMinutesFor(startMin: 21 * 60, endMin: 4 * 60), 420);
    });
  });

  group('ShiftGenerator', () {
    test('reparte apertura y segundo turno y equilibra las horas', () {
      final role = _role(1, 'Sala', Floor.plantaBaja, note: 'Evento privado');
      final employees = [
        _user(1, 'Ana', role, opener: true),
        _user(2, 'Luis', role, opener: true),
      ];

      // Octubre de 2026 tiene 10 noches de viernes/sábado.
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: employees,
        specialDays: const {},
      );

      expect(shifts.length, 20);
      expect(shifts.every((s) => s.status == ShiftStatus.draft), isTrue);
      expect(shifts.every((s) => s.note == 'Evento privado'), isTrue);

      for (final date in shifts.map((s) => s.date).toSet()) {
        final ofDay = shifts.where((s) => s.date == date).toList();
        expect(ofDay.length, 2);
        final starts = ofDay.map((s) => s.startMin).toSet();
        expect(starts, {16 * 60, 21 * 60});
        expect(ofDay.every((s) => s.breakMin == 0), isTrue);
      }

      final byEmployee = <int, int>{};
      for (final shift in shifts) {
        byEmployee[shift.userId] =
            (byEmployee[shift.userId] ?? 0) + shift.workedMinutes;
      }
      expect(byEmployee[1], byEmployee[2]);
      expect(byEmployee[1], 60 * 60); // 10 noches × 12 h / 2
    });

    test('con una sola persona en la planta cubre el turno completo', () {
      final role = _role(1, 'Karaoke', Floor.karaoke);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [_user(1, 'Ana', role, opener: true)],
        specialDays: const {},
      );

      expect(shifts.length, 10);
      expect(shifts.every((s) => s.startMin == 16 * 60), isTrue);
      expect(shifts.every((s) => s.endMin == 4 * 60), isTrue);
      expect(shifts.every((s) => s.breakMin == 40), isTrue);
      expect(shifts.every((s) => s.workedMinutes == 680), isTrue);
    });

    test('ignora empleados inactivos', () {
      final role = _role(1, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', role, opener: true),
          _user(2, 'Luis', role, active: false),
        ],
        specialDays: const {},
      );

      expect(shifts, isNotEmpty);
      expect(shifts.every((s) => s.userId == 1), isTrue);
    });

    test('respeta los cierres y no genera aperturas extra', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final employees = [
        _user(1, 'Ana', role, opener: true),
        _user(2, 'Luis', role, opener: true),
      ];
      final closed = SpecialDay('2026-10-02', open: false);
      final thursday = SpecialDay('2026-10-01', open: true);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: employees,
        specialDays: {
          closed.date: closed,
          thursday.date: thursday,
        },
      );

      expect(shifts.any((s) => s.date == '2026-10-02'), isFalse);
      expect(shifts.any((s) => s.date == '2026-10-01'), isFalse);
      expect(shifts.length, 18); // 9 noches × 2 personas
    });

    test('equilibra tres personas en la misma planta', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final employees = [
        _user(1, 'Ana', role, opener: true),
        _user(2, 'Luis', role, opener: true),
        _user(3, 'Marta', role, opener: true),
      ];

      // Abril de 2027 tiene 9 noches: el reparto adaptativo iguala las horas.
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2027, 4),
        users: employees,
        specialDays: const {},
      );

      final byEmployee = <int, int>{};
      for (final shift in shifts) {
        byEmployee[shift.userId] =
            (byEmployee[shift.userId] ?? 0) + shift.workedMinutes;
      }
      expect(byEmployee.values.toSet().length, 1);
      expect(byEmployee[1], 57 * 60); // 9 noches × 19 h / 3
    });

    test('respeta los días que puede trabajar cada empleado', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final employees = [
        // Ana solo trabaja los viernes; Luis, solo los sábados.
        _user(1, 'Ana', role, opener: true, workingDays: {
          DateTime.friday,
        }),
        _user(2, 'Luis', role, opener: true, workingDays: {
          DateTime.saturday,
        }),
      ];
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: employees,
        specialDays: const {},
      );

      for (final shift in shifts) {
        final weekday = DateTime.parse(shift.date).weekday;
        if (shift.userId == 1) expect(weekday, DateTime.friday);
        if (shift.userId == 2) expect(weekday, DateTime.saturday);
      }
      // Al no coincidir nunca, cada uno cubre su noche en solitario.
      expect(shifts.any((s) => s.userId == 1), isTrue);
      expect(shifts.any((s) => s.userId == 2), isTrue);
    });

    test('cada planta usa solo a su personal', () {
      final baja = _role(1, 'Sala', Floor.plantaBaja);
      final karaoke = _role(2, 'Karaoke', Floor.karaoke);
      final terraza = _role(3, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', baja, opener: true),
          _user(2, 'Luis', karaoke, opener: true),
          _user(3, 'Marta', terraza, opener: true),
        ],
        specialDays: const {},
      );

      for (final shift in shifts) {
        expect(
            shift.floor,
            shift.userId == 1
                ? Floor.plantaBaja
                : shift.userId == 2
                    ? Floor.karaoke
                    : Floor.terraza);
      }
      expect(shifts.where((s) => s.floor == Floor.karaoke).length, 10);
    });

    test('solo los empleados con opener abren', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final employees = [
        _user(1, 'Ana', role, opener: true),
        _user(2, 'Luis', role),
        _user(3, 'Marta', role),
      ];
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: employees,
        specialDays: const {},
      );

      // Ana es la única que puede abrir: hace la apertura todas las noches y
      // nadie sin opener empieza a las 16:00.
      final openings = shifts.where((s) => s.startMin == 16 * 60);
      expect(openings, isNotEmpty);
      expect(openings.every((s) => s.userId == 1), isTrue);
      expect(shifts.any((s) => s.userId == 2), isTrue);
      expect(shifts.any((s) => s.userId == 3), isTrue);
    });

    test('sin opener disponible la planta no se programa', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Luis', role),
          _user(2, 'Marta', role),
        ],
        specialDays: const {},
      );

      expect(shifts, isEmpty);
    });

    test('una sola persona sin opener no abre', () {
      final role = _role(1, 'Karaoke', Floor.karaoke);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [_user(1, 'Ana', role)],
        specialDays: const {},
      );

      expect(shifts, isEmpty);
    });

    test('los viernes la terraza abre a las 21:00 con dos personas', () {
      final terraza = _role(1, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', terraza, opener: true),
          _user(2, 'Luis', terraza),
        ],
        specialDays: const {},
      );

      final fridays = _datesOn(shifts, DateTime.friday);
      expect(fridays, isNotEmpty);
      for (final date in fridays) {
        final day = _day(shifts, date);
        expect(day.length, 2, reason: date);
        // La terraza no abre a las 16:00: todos entran a las 21:00.
        expect(_atOpening(day), 0, reason: date);
        expect(
          day.every((s) => s.startMin == ShiftGenerator.openingEnd),
          isTrue,
          reason: date,
        );
        expect(_atPeak(day), 2, reason: date);
      }
    });

    test('los viernes la terraza programa a todos los disponibles', () {
      final terraza = _role(1, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', terraza, opener: true),
          _user(2, 'Luis', terraza),
          _user(3, 'Marta', terraza),
        ],
        specialDays: const {},
      );

      for (final date in _datesOn(shifts, DateTime.friday)) {
        final day = _day(shifts, date);
        expect(day.length, 3, reason: date);
        expect(
          day.every((s) => s.startMin == ShiftGenerator.openingEnd),
          isTrue,
          reason: date,
        );
        expect(_atPeak(day), greaterThanOrEqualTo(2), reason: date);
      }
    });

    test('la terraza tiene dos personas desde las 16:00 los sábados', () {
      final terraza = _role(1, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', terraza, opener: true),
          _user(2, 'Luis', terraza, opener: true),
        ],
        specialDays: const {},
      );

      final saturdays = _datesOn(shifts, DateTime.saturday);
      expect(saturdays, isNotEmpty);
      for (final date in saturdays) {
        final day = _day(shifts, date);
        expect(day.length, 2, reason: date);
        expect(_atOpening(day), greaterThanOrEqualTo(2), reason: date);
        expect(_atPeak(day), greaterThanOrEqualTo(2), reason: date);
      }
    });

    test('la terraza cubre ambos tramos con tres personas', () {
      final terraza = _role(1, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', terraza, opener: true),
          _user(2, 'Luis', terraza, opener: true),
          _user(3, 'Marta', terraza),
        ],
        specialDays: const {},
      );

      for (final date in _datesOn(shifts, DateTime.saturday)) {
        final day = _day(shifts, date);
        expect(day.length, 3, reason: date);
        expect(_atOpening(day), 2, reason: date);
        expect(_atPeak(day), 2, reason: date);
        // Un turno completo cubre la apertura y el segundo turno.
        expect(
          day
              .where((s) =>
                  s.startMin == ShiftGenerator.openingStart &&
                  s.endMin == ShiftGenerator.closingEnd)
              .length,
          1,
          reason: date,
        );
      }
    });

    test('la regla de dos personas solo aplica a la terraza', () {
      final sala = _role(1, 'Sala', Floor.plantaBaja);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        users: [
          _user(1, 'Ana', sala, opener: true),
          _user(2, 'Luis', sala, opener: true),
        ],
        specialDays: const {},
      );

      for (final date in _datesOn(shifts, DateTime.saturday)) {
        final day = _day(shifts, date);
        expect(_atOpening(day), 1, reason: date);
        expect(_atPeak(day), 1, reason: date);
      }
    });
  });

  test('roleFromList usa la instancia de la lista para el desplegable', () {
    final userRole = _role(1, 'Sala', Floor.plantaBaja);
    final listRole = _role(1, 'Sala', Floor.plantaBaja);

    expect(roleFromList([listRole], userRole), same(listRole));
    expect(roleFromList([], userRole), isNull);
    expect(roleFromList([listRole], null), isNull);
  });
}
