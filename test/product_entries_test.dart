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
  CrateType? box,
}) =>
    Product(
      id: id,
      name: name,
      category: category,
      groupName: group,
      subcategory: sub,
      image: image,
      groupImage: groupImage,
      box: box ?? const CrateType('Caja', 24, 1, 1, 1, 5),
    );

/// Tipo de caja de las botellas de alcohol.
const CrateType _bottleBox =
    CrateType('Botella', 1, 1, 1, 1, 24, isBottle: true);

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
        ['Aquarius', 'Aquarius Limón', 'Aquarius Piña'], // ordenado por nombre
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
      // La etiqueta es siempre el nombre, tenga o no subcategoría.
      expect(
        group.products.map(ProductEntry.label),
        ['Aquarius', 'Aquarius Limón'],
      );
    });

    test('las botellas de alcohol se agrupan por tipo (grupo)', () {
      final entries = buildProductEntries([
        _p(1, 'Barceló Imperial',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
        _p(2, 'Barceló Añejo',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
        _p(3, 'Havana Club 7',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
        _p(4, 'Havana Club 3',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
      ]);

      expect(entries, hasLength(1));
      final group = entries.single;
      expect(group.isGroup, isTrue);
      expect(group.groupName, 'Ron');
      expect(group.products, hasLength(4));
      // Las botellas se titulan con su nombre, no con la marca.
      expect(
        group.products.map(ProductEntry.label),
        containsAll([
          'Barceló Imperial',
          'Barceló Añejo',
          'Havana Club 7',
          'Havana Club 3',
        ]),
      );
    });

    test('dentro del tipo, las botellas se separan por marca', () {
      final entry = buildProductEntries([
        _p(1, 'Barceló Imperial',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
        _p(2, 'Havana Club 7',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
        _p(3, 'Barceló Añejo',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
        _p(4, 'Havana Club 3',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
      ]).single;

      final subgroups = buildProductSubgroups(entry);
      expect(subgroups.map((subgroup) => subgroup.name),
          ['Barceló', 'Havana Club']);
      expect(
        subgroups.first.products.map(ProductEntry.label),
        ['Barceló Añejo', 'Barceló Imperial'],
      );
      expect(
        subgroups.last.products.map(ProductEntry.label),
        ['Havana Club 3', 'Havana Club 7'],
      );
    });

    test('las botellas sin marca van al final, sin cabecera', () {
      final entry = buildProductEntries([
        _p(1, 'Botella suelta',
            category: 'Alcohol', group: 'Ron', box: _bottleBox),
        _p(2, 'Barceló Añejo',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
        _p(3, 'Barceló Imperial',
            category: 'Alcohol', group: 'Ron', sub: 'Barceló', box: _bottleBox),
      ]).single;

      final subgroups = buildProductSubgroups(entry);
      expect(subgroups.map((subgroup) => subgroup.name), ['Barceló', '']);
      expect(subgroups.last.hasName, isFalse);
      expect(subgroups.last.products.single.name, 'Botella suelta');
    });

    test('no se subdivide un grupo que no es de botellas', () {
      final entry = buildProductEntries([
        _p(1, 'Coca-Cola Original', group: 'Coca-Cola', sub: 'Original'),
        _p(2, 'Coca-Cola Zero', group: 'Coca-Cola', sub: 'Zero'),
      ]).single;

      // Aunque tenga subcategorías, no es alcohol: se muestra la lista normal.
      expect(buildProductSubgroups(entry), isEmpty);
    });

    test('la misma marca en tipos distintos no se mezcla', () {
      final entries = buildProductEntries([
        _p(1, 'Ron Havana',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
        _p(2, 'Ron Havana 7',
            category: 'Alcohol',
            group: 'Ron',
            sub: 'Havana Club',
            box: _bottleBox),
        _p(3, 'Whisky Havana',
            category: 'Alcohol',
            group: 'Whisky',
            sub: 'Havana Club',
            box: _bottleBox),
        _p(4, 'Whisky Havana 12',
            category: 'Alcohol',
            group: 'Whisky',
            sub: 'Havana Club',
            box: _bottleBox),
      ]);

      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.products.first.groupName).toSet(),
        {'Ron', 'Whisky'},
      );
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

    test('ordena alfabéticamente mezclando grupos y productos sueltos', () {
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
      // Orden A-Z por el nombre visible, sin separar grupos de sueltos.
      expect(names, ['Agua', 'Aquarius', 'Coca-Cola', 'Fanta']);
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
      expect(names, ['Agua', 'Bliss', 'Coca-Cola']);
    });

    test('no mezcla grupos con el mismo nombre en categorías distintas', () {
      final entries = buildProductEntries([
        _p(1, 'Coca-Cola',
            category: 'Refrescos', group: 'Cola', sub: 'Original'),
        _p(2, 'Coca-Cola Zero',
            category: 'Refrescos', group: 'Cola', sub: 'Zero'),
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
        _p(1, 'Cruzcampo',
            group: 'Cruzcampo',
            sub: 'Pilsen',
            groupImage: 'lib/img/cruzcampo.jfif'),
        _p(2, '1904',
            group: 'Cruzcampo',
            sub: '1904',
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
