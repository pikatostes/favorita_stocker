import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';

void main() {
  group('Product', () {
    test('aplica los valores por defecto', () {
      final p = Product(name: 'Cruzcampo');

      expect(p.id, isNull);
      expect(p.category, 'Otros');
      expect(p.unitsPerBox, 24);
      expect(p.size, 1);
      expect(p.height, 1);
      expect(p.format, 1);
      expect(p.crateName, '');
      expect(p.tripCapacity, 5);
    });

    test('un producto correcto no da error de validación', () {
      expect(
        Product(name: 'Cruzcampo', category: 'Cervezas').validationError,
        isNull,
      );
    });

    test('exige nombre y categoría', () {
      expect(Product(name: '   ').validationError, isNotNull);
      expect(Product(name: 'X', category: '  ').validationError, isNotNull);
    });

    test('exige grupo y subcategoría juntos', () {
      expect(
        Product(name: 'X', groupName: 'Coca-Cola').validationError,
        isNotNull,
      );
      expect(
        Product(name: 'X', subcategory: 'Zero').validationError,
        isNotNull,
      );
      expect(
        Product(
          name: 'X',
          groupName: 'Coca-Cola',
          subcategory: 'Zero',
        ).validationError,
        isNull,
      );
    });

    test('rechaza medidas y cantidades no positivas', () {
      expect(Product(name: 'X', unitsPerBox: 0).validationError, isNotNull);
      expect(Product(name: 'X', size: 0).validationError, isNotNull);
      expect(Product(name: 'X', height: 0).validationError, isNotNull);
      expect(Product(name: 'X', format: 0).validationError, isNotNull);
      expect(Product(name: 'X', tripCapacity: 0).validationError, isNotNull);
    });

    test('toMap/fromMap conservan todos los datos', () {
      final p = Product(
        id: 7,
        name: 'Coca-Cola',
        category: 'Refrescos y zumos',
        groupName: 'Coca-Cola',
        subcategory: 'Original',
        image: 'lib/img/cola.png',
        unitsPerBox: 24,
        size: 1,
        height: 0.5,
        format: 1,
        crateName: 'Cola',
        tripCapacity: 6,
      );

      final restored = Product.fromMap({'id': 7, ...p.toMap()});

      expect(restored.id, 7);
      expect(restored.name, 'Coca-Cola');
      expect(restored.category, 'Refrescos y zumos');
      expect(restored.groupName, 'Coca-Cola');
      expect(restored.subcategory, 'Original');
      expect(restored.image, 'lib/img/cola.png');
      expect(restored.unitsPerBox, 24);
      expect(restored.height, 0.5);
      expect(restored.crateName, 'Cola');
      expect(restored.tripCapacity, 6);
    });

    test('boxInfo describe la caja del producto', () {
      final p = Product(
        name: 'Coca-Cola',
        unitsPerBox: 24,
        size: 1,
        height: 0.5,
        format: 1,
        crateName: 'Cola',
        tripCapacity: 6,
      );

      expect(p.boxInfo, 'Cola · 24 uds · T1 A0.5 F1 · 6/viaje');
      expect(
        Product(name: 'X').boxInfo,
        'Caja · 24 uds · T1 A1 F1 · 5/viaje',
      );
    });
  });

  group('CrateType', () {
    test('guarda los atributos de la caja', () {
      const crate = CrateType('Cola', 24, 1, 0.5, 1, 6);

      expect(crate.name, 'Cola');
      expect(crate.units, 24);
      expect(crate.size, 1);
      expect(crate.height, 0.5);
      expect(crate.format, 1);
      expect(crate.trip, 6);
    });
  });

  group('Forecast', () {
    test('redondea las cajas hacia arriba', () {
      final p = Product(name: 'X', unitsPerBox: 24);

      expect(Forecast(p, 0).boxes, 0);
      expect(Forecast(p, 1).boxes, 1);
      expect(Forecast(p, 24).boxes, 1);
      expect(Forecast(p, 25).boxes, 2);
    });
  });

  group('SpecialDay', () {
    test('interpreta el flag open como booleano', () {
      final open = SpecialDay.fromMap({'date': '2026-01-02', 'open': 1, 'note': 'x'});
      final closed = SpecialDay.fromMap({'date': '2026-01-02', 'open': 0});

      expect(open.open, isTrue);
      expect(open.note, 'x');
      expect(closed.open, isFalse);
      expect(closed.note, '');
    });
  });
}
