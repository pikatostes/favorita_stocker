import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/turnos/schedule/shift_overlap.dart';
import 'package:stock_bar/shifts.dart';

Shift _shift({
  int startMin = 17 * 60,
  int endMin = 20 * 60,
  int userId = 1,
}) =>
    Shift(
      date: '2026-11-20',
      userId: userId,
      userName: 'Ana',
      position: JobPosition.camarero,
      positionName: 'Camarero',
      floor: Floor.plantaBaja,
      startMin: startMin,
      endMin: endMin,
      breakMin: 0,
    );

void main() {
  group('minutesOverlap', () {
    test('franjas separadas no se solapan', () {
      expect(
        minutesOverlap(17 * 60, 20 * 60, 21 * 60, 3 * 60),
        isFalse,
      );
    });

    test('franjas que solo se tocan no se solapan', () {
      expect(
        minutesOverlap(17 * 60, 20 * 60, 20 * 60, 22 * 60),
        isFalse,
      );
    });

    test('detecta solape dentro de la misma tarde', () {
      expect(
        minutesOverlap(17 * 60, 20 * 60, 18 * 60, 22 * 60),
        isTrue,
      );
    });

    test('detecta una franja de madrugada dentro de otra que cruza medianoche',
        () {
      // 23:00–04:00 contiene a 02:00–03:00 aunque end < start.
      expect(
        minutesOverlap(23 * 60, 4 * 60, 2 * 60, 3 * 60),
        isTrue,
      );
    });

    test('una franja de madrugada no se solapa con otra de la tarde', () {
      expect(
        minutesOverlap(2 * 60, 3 * 60, 17 * 60, 20 * 60),
        isFalse,
      );
    });
  });

  group('firstOverlappingShift', () {
    test('devuelve el turno que pisa la franja de la persona indicada', () {
      final shift = _shift(startMin: 17 * 60, endMin: 20 * 60);

      expect(
        firstOverlappingShift(
          [shift],
          startMin: 18 * 60,
          endMin: 19 * 60,
          userId: 1,
        ),
        same(shift),
      );
    });

    test('ignora a otras personas', () {
      final shift = _shift(userId: 2);

      expect(
        firstOverlappingShift(
          [shift],
          startMin: 18 * 60,
          endMin: 19 * 60,
          userId: 1,
        ),
        isNull,
      );
    });

    test('permite un turno no solapado de la misma persona', () {
      final shift = _shift(startMin: 17 * 60, endMin: 20 * 60);

      expect(
        firstOverlappingShift(
          [shift],
          startMin: 21 * 60,
          endMin: 3 * 60,
          userId: 1,
        ),
        isNull,
      );
    });

    test('skip permite ignorar un turno ya tratado', () {
      final shift = _shift();

      expect(
        firstOverlappingShift(
          [shift],
          startMin: 17 * 60,
          endMin: 20 * 60,
          userId: 1,
          skip: (candidate) => candidate == shift,
        ),
        isNull,
      );
    });
  });
}
