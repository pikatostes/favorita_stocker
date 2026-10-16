import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/product_entries.dart';

Product _p(
  int id,
  String name, {
  String category = 'Cat',
  String? group,
  String? sub,
  String? image,
  String? groupImage,
}) =>
    Product(
      id: id,
      name: name,
      category: category,
      groupName: group,
      subcategory: sub,
      image: image,
      groupImage: groupImage,
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

    test('coloca los grupos de variantes antes que los productos sueltos', () {
      final entries = buildProductEntries([
        _p(1, 'Agua', category: 'R'),
        _p(2, 'Aquarius', category: 'R', group: 'Aquarius', sub: 'Naranja'),
        _p(3, 'Aquarius Limón', category: 'R', group: 'Aquarius', sub: 'Limón'),
        _p(4, 'Fanta', category: 'R'),
        _p(5, 'Coca-Cola', category: 'R', group: 'Coca-Cola', sub: 'Original'),
        _p(6, 'Coca-Cola Zero', category: 'R', group: 'Coca-Cola', sub: 'Zero'),
      ]);

      final names = entries
          .map((e) => e.isGroup ? e.groupName : e.products.single.name)
          .toList();
      // Primero los grupos (en su orden original), luego los sueltos.
      expect(names, ['Aquarius', 'Coca-Cola', 'Agua', 'Fanta']);
      expect(entries.take(2).every((e) => e.isGroup), isTrue);
    });

    test('un grupo de una sola subcategoría cuenta como producto suelto', () {
      final entries = buildProductEntries([
        _p(1, 'Bliss', group: 'Bliss', sub: 'Tónica'),
        _p(2, 'Agua'),
        _p(3, 'Coca-Cola', group: 'Coca-Cola', sub: 'Original'),
        _p(4, 'Coca-Cola Zero', group: 'Coca-Cola', sub: 'Zero'),
      ]);

      final names = entries
          .map((e) => e.isGroup ? e.groupName : e.products.single.name)
          .toList();
      expect(names, ['Coca-Cola', 'Bliss', 'Agua']);
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

    test('imagen: la del grupo para grupos y la propia para sueltos', () {
      final entries = buildProductEntries([
        _p(1, 'Cruzcampo', group: 'Cruzcampo', sub: 'Pilsen',
            groupImage: 'lib/img/cruzcampo.jfif'),
        _p(2, '1904', group: 'Cruzcampo', sub: '1904',
            groupImage: 'lib/img/cruzcampo.jfif'),
        _p(3, 'Fanta', image: 'lib/img/fanta.png'),
      ]);

      expect(entries[0].isGroup, isTrue);
      expect(entries[0].image, 'lib/img/cruzcampo.jfif');
      expect(entries[1].isGroup, isFalse);
      expect(entries[1].image, 'lib/img/fanta.png');
    });

    test('un grupo sin imagen devuelve null (placeholder)', () {
      final entries = buildProductEntries([
        _p(1, 'Aquarius', group: 'Aquarius', sub: 'Naranja'),
        _p(2, 'Aquarius Limón', group: 'Aquarius', sub: 'Limón'),
      ]);

      expect(entries.single.isGroup, isTrue);
      expect(entries.single.image, isNull);
    });
  });
}
