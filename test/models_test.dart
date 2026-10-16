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
      expect(p.width, 1);
      expect(p.format, 1);
      expect(p.crateName, 'Caja');
      expect(p.tripCapacity, 5);
    });

    test('un producto correcto no da error de validación', () {
      expect(
        Product(name: 'Cruzcampo', category: 'Cervezas', groupName: 'Cruzcampo')
            .validationError,
        isNull,
      );
    });

    test('exige nombre, categoría y grupo', () {
      expect(Product(name: '   ', category: 'X', groupName: 'g').validationError,
          isNotNull);
      expect(Product(name: 'X', category: '  ', groupName: 'g').validationError,
          isNotNull);
      // El grupo es obligatorio (la categoría se deriva de él).
      expect(Product(name: 'X', category: 'X').validationError, isNotNull);
    });

    test('la subcategoría es opcional', () {
      expect(Product(name: 'X', category: 'X', groupName: 'g').validationError,
          isNull);
      expect(
        Product(name: 'X', category: 'X', groupName: 'g', subcategory: 'Zero')
            .validationError,
        isNull,
      );
    });

    test('rechaza medidas y cantidades no positivas', () {
      Product withBox(CrateType box) =>
          Product(name: 'X', category: 'X', groupName: 'g', box: box);

      expect(withBox(const CrateType('Caja', 0, 1, 1, 1, 5)).validationError,
          isNotNull);
      expect(withBox(const CrateType('Caja', 24, 0, 1, 1, 5)).validationError,
          isNotNull);
      expect(withBox(const CrateType('Caja', 24, 1, 0, 1, 5)).validationError,
          isNotNull);
      expect(withBox(const CrateType('Caja', 24, 1, 1, 1, 0)).validationError,
          isNotNull);
      const zeroWidth = CrateType('Caja', 24, 1, 1, 1, 5, width: 0);
      expect(withBox(zeroWidth).validationError, isNotNull);
    });

    test('fromRow conserva todos los datos', () {
      final p = Product.fromRow({
        'id': 7,
        'name': 'Coca-Cola',
        'category': 'Refrescos y zumos',
        'group_name': 'Coca-Cola',
        'subcategory': 'Original',
        'image': 'lib/img/cola.png',
        'box_name': 'Cola',
        'units_per_box': 24,
        'size': 1.0,
        'height': 0.5,
        'width': 1.5,
        'format': 1,
        'trip_capacity': 6,
      });

      expect(p.id, 7);
      expect(p.name, 'Coca-Cola');
      expect(p.category, 'Refrescos y zumos');
      expect(p.groupName, 'Coca-Cola');
      expect(p.subcategory, 'Original');
      expect(p.image, 'lib/img/cola.png');
      expect(p.crateName, 'Cola');
      expect(p.unitsPerBox, 24);
      expect(p.height, 0.5);
      expect(p.width, 1.5);
      expect(p.tripCapacity, 6);
    });

    test('boxInfo describe la caja del producto', () {
      final p = Product(
        name: 'Coca-Cola',
        box: const CrateType('Cola', 24, 1, 0.5, 1, 6),
      );

      expect(p.boxInfo, 'Cola · 24 uds · T1 A0.5 An1 F1 · 6/viaje');
      expect(
        Product(name: 'X').boxInfo,
        'Caja · 24 uds · T1 A1 An1 F1 · 5/viaje',
      );
    });
  });

  group('CrateType', () {
    test('guarda los atributos de la caja', () {
      const crate = CrateType('Cola', 24, 1, 0.5, 1, 6, width: 2);

      expect(crate.name, 'Cola');
      expect(crate.units, 24);
      expect(crate.size, 1);
      expect(crate.height, 0.5);
      expect(crate.width, 2);
      expect(crate.format, 1);
      expect(crate.trip, 6);
    });
  });

  group('Forecast', () {
    test('redondea las cajas hacia arriba', () {
      final p = Product(name: 'X', box: const CrateType('Caja', 24, 1, 1, 1, 5));

      expect(Forecast(p, 0).boxes, 0);
      expect(Forecast(p, 1).boxes, 1);
      expect(Forecast(p, 24).boxes, 1);
      expect(Forecast(p, 25).boxes, 2);
    });
  });

  group('SpecialDay', () {
    test('interpreta el flag open como booleano', () {
      final open =
          SpecialDay.fromMap({'date': '2026-01-02', 'open': 1, 'note': 'x'});
      final closed = SpecialDay.fromMap({'date': '2026-01-02', 'open': 0});

      expect(open.open, isTrue);
      expect(open.note, 'x');
      expect(closed.open, isFalse);
      expect(closed.note, '');
    });
  });
}
