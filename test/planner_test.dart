import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/planner.dart';

/// Producto de apoyo: todos los tests usan cajas con los mismos atributos
/// salvo que se indique lo contrario.
Product _product(
  int id, {
  int unitsPerBox = 24,
  double size = 1,
  double height = 1,
  int format = 1,
  String crateName = 'Caja',
  int tripCapacity = 5,
}) =>
    Product(
      id: id,
      name: 'Producto $id',
      groupName: 'Grupo $id',
      box: CrateType(crateName, unitsPerBox, size, height, format, tripCapacity),
    );

void main() {
  group('Planner.build', () {
    test('sin cantidades no monta nada', () {
      final plan = Planner.build([_product(1)], const {});

      expect(plan.trips, isEmpty);
      expect(plan.crates, isEmpty);
      expect(plan.bottles, 0);
    });

    test('preferFull convierte los botellines en cajas dedicadas', () {
      final plan = Planner.build([_product(1)], {1: 48}, preferFull: true);

      expect(plan.bottles, 48);
      expect(plan.crates.length, 2);
      expect(plan.crates.every((c) => c.dedicated), isTrue);
      expect(plan.crates.every((c) => c.filled == 24), isTrue);
      expect(plan.crates.every((c) => c.capacity == 24), isTrue);
      expect(plan.trips.length, 1);
    });

    test('preferFull deja aparte los botellines sobrantes', () {
      // 50 = 2 cajas completas (48) + 2 botellines sueltos.
      final plan = Planner.build([_product(1)], {1: 50}, preferFull: true);

      expect(plan.bottles, 50);
      expect(plan.crates.length, 3);
      expect(plan.crates.where((c) => c.dedicated).length, 2);
      expect(plan.crates.where((c) => !c.dedicated).single.filled, 2);
    });

    test('sin preferFull los botellines se mezclan en cajas', () {
      final plan = Planner.build([_product(1)], {1: 48});

      expect(plan.crates.length, 2);
      expect(plan.crates.every((c) => !c.dedicated), isTrue);
      expect(plan.crates.every((c) => c.filled == 24), isTrue);
    });

    test('dos productos del mismo tipo comparten caja mezclada', () {
      final plan = Planner.build([_product(1), _product(2)], {1: 12, 2: 12});

      expect(plan.crates.length, 1);
      final crate = plan.crates.single;
      expect(crate.filled, 24);
      expect(crate.lines.length, 2);
      expect(crate.dedicated, isFalse);
    });

    test('cajas completas pedidas a mano salen dedicadas', () {
      final plan = Planner.build([_product(1)], const {}, fullBoxes: {1: 2});

      expect(plan.bottles, 48);
      expect(plan.crates.length, 2);
      expect(plan.crates.every((c) => c.dedicated), isTrue);
      expect(plan.crates.every((c) => c.lines.single.qty == 24), isTrue);
    });

    test('tipos de caja distintos no se mezclan', () {
      final cola = _product(1, unitsPerBox: 24, crateName: 'Cola');
      final agua =
          _product(2, unitsPerBox: 20, size: 2, format: 3, crateName: 'Agua');

      final plan = Planner.build([cola, agua], {1: 10, 2: 10});

      expect(plan.crates.length, 2);
      expect(plan.crates.map((c) => c.name).toSet(), {'Cola', 'Agua'});
      expect(plan.crates.every((c) => c.lines.length == 1), isTrue);
      expect(plan.crates.every((c) => c.filled == 10), isTrue);
    });

    test('reparte las cajas en viajes según la capacidad del carro', () {
      final plan = Planner.build([_product(1, tripCapacity: 1)], {1: 72});

      expect(plan.crates.length, 3);
      expect(plan.trips.length, 3);
      expect(plan.trips.every((t) => t.crates.length == 1), isTrue);
      expect(plan.trips.every((t) => t.percent == 100), isTrue);
    });
  });
}
