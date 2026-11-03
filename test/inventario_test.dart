import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/product_entries.dart';

/// Producto de prueba con una caja de [units] botellines.
Product _product(
  String name, {
  String category = 'Refrescos',
  String? group,
  String? subcategory,
  int unitsInStock = 0,
  String? image,
  String? groupImage,
  int unitsPerBox = 24,
}) =>
    Product(
      name: name,
      category: category,
      groupName: group,
      subcategory: subcategory,
      unitInStock: unitsInStock,
      image: image,
      groupImage: groupImage,
      box: CrateType('Caja', unitsPerBox, 1, 1, 1, 5),
    );

void main() {
  group('stock en cajas completas y unidades sobrantes', () {
    test('separa cajas completas de las unidades sueltas', () {
      final product = _product('Coca-Cola', unitsInStock: 53);

      expect(product.stockBoxes, 2);
      expect(product.stockLooseUnits, 5);
    });

    test('no inventa cajas cuando no llega a una completa', () {
      final product = _product('Coca-Cola', unitsInStock: 7);

      expect(product.stockBoxes, 0);
      expect(product.stockLooseUnits, 7);
    });

    test('el stock vacío son cero cajas y cero unidades', () {
      final product = _product('Coca-Cola');

      expect(product.stockBoxes, 0);
      expect(product.stockLooseUnits, 0);
    });
  });

  group('agrupación del catálogo', () {
    test('las variantes de un mismo grupo se muestran juntas', () {
      final entries = buildProductEntries([
        _product('Coca-Cola', group: 'Coca-Cola', subcategory: 'Zero'),
        _product('Coca-Cola', group: 'Coca-Cola', subcategory: 'Original'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.isGroup, isTrue);
      expect(entries.single.groupName, 'Coca-Cola');
      expect(
        entries.single.products.map(ProductEntry.label),
        ['Original', 'Zero'],
      );
    });

    test('un grupo con una sola variante se muestra suelto', () {
      final entries = buildProductEntries([
        _product('Cruzcampo', group: 'Cruzcampo'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.isGroup, isFalse);
    });

    test('productos sin grupo van sueltos y después de los grupos', () {
      final entries = buildProductEntries([
        _product('Agua', group: null),
        _product('Coca-Cola', group: 'Coca-Cola', subcategory: 'Zero'),
        _product('Coca-Cola', group: 'Coca-Cola', subcategory: 'Original'),
      ]);

      expect(entries, hasLength(2));
      expect(entries.first.isGroup, isTrue);
      expect(entries.last.isGroup, isFalse);
      expect(entries.last.products.single.name, 'Agua');
    });

    test('dos categorías pueden tener grupos con el mismo nombre', () {
      final entries = buildProductEntries([
        _product(
          'Cerveza',
          category: 'Cerveza',
          group: 'Especial',
          subcategory: 'Rubia',
        ),
        _product(
          'Cerveza',
          category: 'Cerveza',
          group: 'Especial',
          subcategory: 'Negra',
        ),
        _product(
          'Refresco',
          category: 'Refrescos',
          group: 'Especial',
          subcategory: 'Limón',
        ),
        _product(
          'Refresco',
          category: 'Refrescos',
          group: 'Especial',
          subcategory: 'Naranja',
        ),
      ]);

      expect(entries, hasLength(2));
      expect(entries.every((entry) => entry.isGroup), isTrue);
      expect(
        entries.map((entry) => entry.products.first.category).toSet(),
        {'Cerveza', 'Refrescos'},
      );
    });

    test('la etiqueta usa la subcategoría y, si falta, el nombre', () {
      expect(
        ProductEntry.label(_product('Coca-Cola', subcategory: 'Zero')),
        'Zero',
      );
      expect(ProductEntry.label(_product('Agua')), 'Agua');
    });

    test('la imagen del grupo se toma de sus variantes', () {
      final entry = ProductEntry.group('Coca-Cola', [
        _product('Coca-Cola', groupImage: null),
        _product('Coca-Cola', groupImage: 'lib/img/coca-cola.png'),
      ]);

      expect(entry.image, 'lib/img/coca-cola.png');
    });
  });

  group('excepciones del calendario', () {
    test('acepta open como booleano o como entero', () {
      expect(
        SpecialDay.fromMap({'date': '2026-12-25', 'open': true}).open,
        isTrue,
      );
      expect(
        SpecialDay.fromMap({'date': '2026-12-25', 'open': 1}).open,
        isTrue,
      );
      expect(
        SpecialDay.fromMap({'date': '2026-12-24', 'open': false}).open,
        isFalse,
      );
      expect(
        SpecialDay.fromMap({'date': '2026-12-24', 'open': 0}).open,
        isFalse,
      );
    });
  });
}
