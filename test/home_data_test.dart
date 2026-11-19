import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/data/home_data.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/shifts.dart';

Product _product(int id, int unitsPerBox) => Product(
      id: id,
      name: 'Producto $id',
      groupName: 'Grupo $id',
      box: CrateType('Caja', unitsPerBox, 1, 1, 1, 5),
    );

void main() {
  group('NightListSummary.fromConsumption', () {
    test('separa cajas completas y botellines sueltos', () {
      final summary = NightListSummary.fromConsumption(
        date: '2026-11-08',
        floor: Floor.terraza,
        saved: {1: 26, 2: 3},
        productsById: {
          1: _product(1, 12),
          2: _product(2, 12),
        },
      );

      expect(summary, isNotNull);
      expect(summary!.date, '2026-11-08');
      expect(summary.floor, Floor.terraza);
      expect(summary.fullBoxes, {1: 2});
      expect(summary.qty, {1: 2, 2: 3});
      expect(summary.totalUnits, 29);
      expect(summary.products, 2);
    });

    test('ignora productos desconocidos y cantidades no positivas', () {
      final summary = NightListSummary.fromConsumption(
        date: '2026-11-08',
        floor: Floor.plantaBaja,
        saved: {1: 0, 99: 5},
        productsById: {1: _product(1, 12)},
      );

      expect(summary, isNull);
    });

    test('sin unidades por caja usa una unidad por caja', () {
      final summary = NightListSummary.fromConsumption(
        date: '2026-11-08',
        floor: Floor.karaoke,
        saved: {1: 3},
        productsById: {1: _product(1, 0)},
      );

      // Sin unidades por caja se usa 1, así que las 3 unidades son cajas.
      expect(summary!.fullBoxes, {1: 3});
      expect(summary.qty, isEmpty);
    });
  });

  group('HomeData.shiftCounts', () {
    test('cuenta los estados del mes en una sola pasada', () {
      final data = _homeData(
        monthShifts: [
          _shift(ShiftStatus.draft),
          _shift(ShiftStatus.published),
          _shift(ShiftStatus.published),
          _shift(ShiftStatus.confirmed),
        ],
      );

      expect(
        data.shiftCounts,
        (drafts: 1, published: 2, confirmed: 1),
      );
    });

    test('sin turnos devuelve contadores a cero', () {
      expect(
        _homeData().shiftCounts,
        (drafts: 0, published: 0, confirmed: 0),
      );
    });
  });
}

Shift _shift(ShiftStatus status) => Shift(
      date: '2026-11-09',
      userId: 1,
      userName: 'Ana',
      roleId: 1,
      roleName: 'Camarero',
      floor: Floor.plantaBaja,
      startMin: 16 * 60,
      endMin: 24 * 60,
      breakMin: 0,
      status: status,
    );

HomeData _homeData({List<Shift> monthShifts = const []}) => HomeData(
      now: DateTime(2026, 11, 9),
      serviceDay: DateTime(2026, 11, 9),
      focusDay: DateTime(2026, 11, 9),
      nextOpen: DateTime(2026, 11, 10),
      openNow: true,
      opensLaterToday: false,
      special: const {},
      users: const [],
      monthShifts: monthShifts,
      focusShifts: const [],
      myUpcoming: const [],
      mySchedulePending: false,
      forecast: null,
      nightList: null,
    );
