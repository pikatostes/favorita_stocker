import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/home/home_data.dart';

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
        saved: {1: 26, 2: 3},
        productsById: {
          1: _product(1, 12),
          2: _product(2, 12),
        },
      );

      expect(summary, isNotNull);
      expect(summary!.date, '2026-11-08');
      expect(summary.fullBoxes, {1: 2});
      expect(summary.qty, {1: 2, 2: 3});
      expect(summary.totalUnits, 29);
      expect(summary.products, 2);
    });

    test('ignora productos desconocidos y cantidades no positivas', () {
      final summary = NightListSummary.fromConsumption(
        date: '2026-11-08',
        saved: {1: 0, 99: 5},
        productsById: {1: _product(1, 12)},
      );

      expect(summary, isNull);
    });

    test('sin unidades por caja usa una unidad por caja', () {
      final summary = NightListSummary.fromConsumption(
        date: '2026-11-08',
        saved: {1: 3},
        productsById: {1: _product(1, 0)},
      );

      // Sin unidades por caja se usa 1, así que las 3 unidades son cajas.
      expect(summary!.fullBoxes, {1: 3});
      expect(summary.qty, isEmpty);
    });
  });
}
