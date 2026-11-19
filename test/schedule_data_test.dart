import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/data/schedule_data.dart';
import 'package:stock_bar/shifts.dart';

Shift _shift(String date, {int userId = 1, String name = 'Ana'}) => Shift(
      date: date,
      userId: userId,
      userName: name,
      roleId: 1,
      roleName: 'Camarero',
      floor: Floor.plantaBaja,
      startMin: 16 * 60,
      endMin: 24 * 60,
      breakMin: 0,
      status: ShiftStatus.published,
    );

void main() {
  group('ScheduleData', () {
    test('agrupa los turnos por fecha una sola vez', () {
      final data = ScheduleData(
        shifts: [
          _shift('2026-11-13'),
          _shift('2026-11-13', userId: 2, name: 'Luis'),
          _shift('2026-11-14'),
        ],
        users: const [],
        special: const {},
      );

      expect(data.byDate.keys, containsAll(['2026-11-13', '2026-11-14']));
      expect(data.shiftsFor('2026-11-13'), hasLength(2));
      expect(data.shiftsFor('2026-11-14'), hasLength(1));
    });

    test('una fecha sin turnos devuelve una lista vacía', () {
      final data = ScheduleData(
        shifts: [_shift('2026-11-13')],
        users: const [],
        special: const {},
      );

      expect(data.shiftsFor('2026-11-20'), isEmpty);
    });

    test('byDate no se puede modificar desde fuera', () {
      final data = ScheduleData(
        shifts: [_shift('2026-11-13')],
        users: const [],
        special: const {},
      );

      expect(
        () => data.byDate['2026-11-14'] = const [],
        throwsUnsupportedError,
      );
      expect(
        () => data.shiftsFor('2026-11-13').add(_shift('2026-11-13')),
        throwsUnsupportedError,
      );
    });

    test('hasUsers indica si hay personal para generar el horario', () {
      expect(
        ScheduleData(
          shifts: const [],
          users: const [],
          special: const {},
        ).hasUsers,
        isFalse,
      );
      expect(
        ScheduleData(
          shifts: const [],
          users: const [AppUser(name: 'Sin puesto')],
          special: const {},
        ).hasUsers,
        isFalse,
      );
    });

    test('usersWithRole deja fuera a quien no tiene puesto', () {
      final data = ScheduleData(
        shifts: const [],
        users: const [
          AppUser(name: 'Ana'),
          AppUser(
            name: 'Luis',
            jobRole: JobRole(id: 1, name: 'Camarero'),
          ),
        ],
        special: const {},
      );

      expect(data.hasUsers, isTrue);
      expect(data.usersWithRole.map((user) => user.name), ['Luis']);
    });
  });
}
