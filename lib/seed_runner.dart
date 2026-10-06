import 'db.dart';
import 'seed.dart';

const _legacyProductMetadataMigration = 'legacy_product_metadata_v1';

const _legacyGroups = <String, ({String group, String subcategory})>{
  'Coca-Cola': (group: 'Coca-Cola', subcategory: 'Original'),
  'Coca-Cola Zero': (group: 'Coca-Cola', subcategory: 'Zero'),
  'Coca-Cola Zero Zero': (group: 'Coca-Cola', subcategory: 'Zero Zero'),
  'Coca-Cola Light': (group: 'Coca-Cola', subcategory: 'Light'),
  'Bliss': (group: 'Bliss', subcategory: 'Tónica'),
  'Bliss Limón': (group: 'Bliss', subcategory: 'Limón'),
  'Bliss Berry': (group: 'Bliss', subcategory: 'Berry'),
  'Bliss Ginger Ale': (group: 'Bliss', subcategory: 'Ginger Ale'),
  'Nestea': (group: 'Nestea', subcategory: 'Té'),
  'Nestea Limón': (group: 'Nestea', subcategory: 'Limón'),
  'Nestea Maracuyá': (group: 'Nestea', subcategory: 'Maracuyá'),
  'Nestea Melocotón': (group: 'Nestea', subcategory: 'Melocotón'),
  'Aquarius': (group: 'Aquarius', subcategory: 'Naranja'),
  'Aquarius Limón': (group: 'Aquarius', subcategory: 'Limón'),
  'Aquarius Piña': (group: 'Aquarius', subcategory: 'Piña'),
  'Aquarius Melocotón': (group: 'Aquarius', subcategory: 'Melocotón'),
  'Zumo': (group: 'Zumo', subcategory: 'Piña'),
  'Zumo Piña': (group: 'Zumo', subcategory: 'Piña'),
  'Zumo Melocotón': (group: 'Zumo', subcategory: 'Melocotón'),
  'Zumo Naranja': (group: 'Zumo', subcategory: 'Naranja'),
};

/// Inserts the starter catalog once and fills metadata for legacy products.
Future<void> initializeSeedData() async {
  final database = await Db.i.db;
  await database.transaction((transaction) async {
    final migration = await transaction.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_legacyProductMetadataMigration],
      limit: 1,
    );
    if (migration.isNotEmpty) return;

    final count = (await transaction.rawQuery(
      'SELECT COUNT(*) AS count FROM products',
    ))
        .single['count'] as int;

    if (count == 0) {
      for (final product in initialProducts) {
        await transaction.insert('products', product.toMap());
      }
    }

    for (final entry in _legacyGroups.entries) {
      await transaction.update(
        'products',
        {
          'group_name': entry.value.group,
          'subcategory': entry.value.subcategory,
        },
        where: "category = 'Refrescos y zumos' AND name = ? "
            'AND group_name IS NULL AND subcategory IS NULL',
        whereArgs: [entry.key],
      );
    }

    const legacyCrates = [
      (
        category: 'Refrescos y zumos',
        size: 1.0,
        height: 0.5,
        format: 1,
        name: 'Cola',
        trip: 6
      ),
      (
        category: 'Refrescos y zumos',
        size: 1.0,
        height: 1.0,
        format: 1,
        name: 'Nestea',
        trip: 5
      ),
      (
        category: 'Refrescos y zumos',
        size: 1.0,
        height: 2.0,
        format: 1,
        name: 'Nestea alto',
        trip: 5
      ),
      (
        category: 'Cervezas y similares',
        size: 1.0,
        height: 1.0,
        format: 2,
        name: 'Cerveza',
        trip: 5
      ),
      (
        category: 'Cervezas y similares',
        size: 2.0,
        height: 1.0,
        format: 2,
        name: 'Cerveza grande',
        trip: 5
      ),
      (
        category: 'Refrescos y zumos',
        size: 2.0,
        height: 1.0,
        format: 3,
        name: 'Agua',
        trip: 5
      ),
    ];
    for (final crate in legacyCrates) {
      await transaction.update(
        'products',
        {'crate_name': crate.name, 'trip_capacity': crate.trip},
        where: 'category = ? AND size = ? AND height = ? AND format = ? '
            'AND crate_name = ?',
        whereArgs: [
          crate.category,
          crate.size,
          crate.height,
          crate.format,
          '',
        ],
      );
    }

    await transaction.insert('app_metadata', {
      'key': _legacyProductMetadataMigration,
      'value': 'complete',
    });
  });
}
