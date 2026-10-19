import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/shifts.dart';

JobRole _role(int id, String name, Floor floor, {String note = ''}) =>
    JobRole(id: id, name: name, floor: floor, note: note);

Employee _employee(int id, String name, JobRole role, {bool active = true}) =>
    Employee(id: id, name: name, role: role, active: active);

void main() {
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
        _employee(1, 'Ana', role),
        _employee(2, 'Luis', role),
      ];

      // Octubre de 2026 tiene 10 noches de viernes/sábado.
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        employees: employees,
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
        byEmployee[shift.employeeId] =
            (byEmployee[shift.employeeId] ?? 0) + shift.workedMinutes;
      }
      expect(byEmployee[1], byEmployee[2]);
      expect(byEmployee[1], 60 * 60); // 10 noches × 12 h / 2
    });

    test('con una sola persona en la planta cubre el turno completo', () {
      final role = _role(1, 'Karaoke', Floor.karaoke);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        employees: [_employee(1, 'Ana', role)],
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
        employees: [
          _employee(1, 'Ana', role),
          _employee(2, 'Luis', role, active: false),
        ],
        specialDays: const {},
      );

      expect(shifts.every((s) => s.employeeId == 1), isTrue);
    });

    test('respeta los cierres y no genera aperturas extra', () {
      final role = _role(1, 'Sala', Floor.plantaBaja);
      final employees = [
        _employee(1, 'Ana', role),
        _employee(2, 'Luis', role),
      ];
      final closed = SpecialDay('2026-10-02', open: false);
      final thursday = SpecialDay('2026-10-01', open: true);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        employees: employees,
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
        _employee(1, 'Ana', role),
        _employee(2, 'Luis', role),
        _employee(3, 'Marta', role),
      ];

      // Abril de 2027 tiene 9 noches: el reparto adaptativo iguala las horas.
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2027, 4),
        employees: employees,
        specialDays: const {},
      );

      final byEmployee = <int, int>{};
      for (final shift in shifts) {
        byEmployee[shift.employeeId] =
            (byEmployee[shift.employeeId] ?? 0) + shift.workedMinutes;
      }
      expect(byEmployee.values.toSet().length, 1);
      expect(byEmployee[1], 57 * 60); // 9 noches × 19 h / 3
    });

    test('cada planta usa solo a su personal', () {
      final baja = _role(1, 'Sala', Floor.plantaBaja);
      final karaoke = _role(2, 'Karaoke', Floor.karaoke);
      final terraza = _role(3, 'Terraza', Floor.terraza);
      final shifts = ShiftGenerator.generateMonth(
        month: DateTime(2026, 10),
        employees: [
          _employee(1, 'Ana', baja),
          _employee(2, 'Luis', karaoke),
          _employee(3, 'Marta', terraza),
        ],
        specialDays: const {},
      );

      for (final shift in shifts) {
        expect(
            shift.floor,
            shift.employeeId == 1
                ? Floor.plantaBaja
                : shift.employeeId == 2
                    ? Floor.karaoke
                    : Floor.terraza);
      }
      expect(shifts.where((s) => s.floor == Floor.karaoke).length, 10);
    });
  });
}
