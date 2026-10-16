import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/product_entries.dart';

Product _p(
  int id,
  String name, {
  String category = 'Cat',
  String? group,
  String? sub,
}) =>
    Product(
      id: id,
      name: name,
      category: category,
      groupName: group,
      subcategory: sub,
    );

void main() {
  group('buildProductEntries', () {
    test('agrupa todas las variantes de un grupo', () {
      final entries = buildProductEntries([
        _p(1, 'Aquarius', group: 'Aquarius', sub: 'Naranja'),
        _p(2, 'Aquarius Limón', group: 'Aquarius', sub: 'Limón'),
        _p(3, 'Aquarius Piña', group: 'Aquarius', sub: 'Piña'),
      ]);

      expect(entries.length, 1);
      final group = entries.single;
      expect(group.isGroup, isTrue);
      expect(group.groupName, 'Aquarius');
      expect(group.products.length, 3);
      expect(
        group.products.map(ProductEntry.label),
        ['Limón', 'Naranja', 'Piña'], // ordenado por etiqueta
      );
    });

    test('una variante sin subcategoría no desaparece del grupo', () {
      final entries = buildProductEntries([
        _p(1, 'Aquarius', group: 'Aquarius', sub: 'Naranja'),
        _p(2, 'Aquarius Limón', group: 'Aquarius'),
      ]);

      expect(entries.length, 1);
      final group = entries.single;
      expect(group.isGroup, isTrue);
      expect(group.products.length, 2);
      // La variante sin subcategoría usa su nombre como etiqueta.
      expect(group.products.map(ProductEntry.label), ['Aquarius Limón', 'Naranja']);
    });

    test('un grupo de un solo producto se muestra suelto', () {
      final entries = buildProductEntries([
        _p(1, 'Cruzcampo', group: 'Cruzcampo'),
      ]);

      expect(entries.single.isGroup, isFalse);
      expect(entries.single.products.single.name, 'Cruzcampo');
    });

    test('un producto sin grupo se muestra suelto', () {
      final entries = buildProductEntries([_p(1, 'Fanta', sub: 'Naranja')]);

      expect(entries.single.isGroup, isFalse);
      expect(entries.single.products.single.name, 'Fanta');
    });

    test('conserva el orden de los productos', () {
      final entries = buildProductEntries([
        _p(1, 'Agua', category: 'R'),
        _p(2, 'Aquarius', category: 'R', group: 'Aquarius', sub: 'Naranja'),
        _p(3, 'Aquarius Limón', category: 'R', group: 'Aquarius', sub: 'Limón'),
        _p(4, 'Fanta', category: 'R'),
      ]);

      final names = entries
          .map((e) => e.isGroup ? e.groupName : e.products.single.name)
          .toList();
      expect(names, ['Agua', 'Aquarius', 'Fanta']);
    });

    test('no mezcla grupos con el mismo nombre en categorías distintas', () {
      final entries = buildProductEntries([
        _p(1, 'Coca-Cola', category: 'Refrescos', group: 'Cola', sub: 'Original'),
        _p(2, 'Coca-Cola Zero', category: 'Refrescos', group: 'Cola', sub: 'Zero'),
        _p(3, 'Cola', category: 'Otra', group: 'Cola', sub: 'Original'),
        _p(4, 'Cola Cero', category: 'Otra', group: 'Cola', sub: 'Zero'),
      ]);

      expect(entries.length, 2);
      expect(entries[0].products.length, 2);
      expect(entries[1].products.length, 2);
      expect(entries[0].products.first.category, 'Refrescos');
      expect(entries[1].products.first.category, 'Otra');
    });
  });
}
