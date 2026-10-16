import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'schedule.dart';

/// Acceso a SQLite. Una fila de `consumption` = producto gastado en una noche.
class Db {
  Db._();
  static final Db i = Db._();
  Database? _db;

  /// Se incrementa con cada escritura; las pantallas escuchan para refrescarse.
  final ValueNotifier<int> version = ValueNotifier(0);
  void _changed() => version.value++;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'stock_bar.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (d, _) async {
        await d.execute('''CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Otros',
          group_name TEXT,
          subcategory TEXT,
          image TEXT,
          units_per_box INTEGER NOT NULL DEFAULT 24,
          size REAL NOT NULL DEFAULT 1,
          height REAL NOT NULL DEFAULT 1,
          format INTEGER NOT NULL DEFAULT 1,
          crate_name TEXT NOT NULL DEFAULT '',
          trip_capacity INTEGER NOT NULL DEFAULT 5)''');
        await _createProductGroups(d);
        await d.execute('''CREATE TABLE app_metadata(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE consumption(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          date TEXT NOT NULL,       -- yyyy-MM-dd del día en que empezó la noche
          quantity INTEGER NOT NULL)''');
        await d.execute('CREATE INDEX idx_cons_date ON consumption(date)');
        await _createSpecialDays(d);
      },
      onUpgrade: (d, oldV, _) async {
        if (oldV < 2) await _createSpecialDays(d);
        if (oldV < 3) {
          await d.execute("ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'");
          await d.execute('ALTER TABLE products ADD COLUMN size REAL NOT NULL DEFAULT 1');
          await d.execute('ALTER TABLE products ADD COLUMN height REAL NOT NULL DEFAULT 1');
          await d.execute('ALTER TABLE products ADD COLUMN format INTEGER NOT NULL DEFAULT 1');
        }
        if (oldV < 4) {
          await d.execute("ALTER TABLE products ADD COLUMN crate_name TEXT NOT NULL DEFAULT ''");
          await d.execute('ALTER TABLE products ADD COLUMN trip_capacity INTEGER NOT NULL DEFAULT 5');
        }
        if (oldV < 5) {
          await d.execute('ALTER TABLE products ADD COLUMN group_name TEXT');
          await d.execute('ALTER TABLE products ADD COLUMN subcategory TEXT');
        }
        if (oldV < 6) {
          await d.execute('''CREATE TABLE app_metadata(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL)''');
        }
        if (oldV < 7) {
          await d.execute('ALTER TABLE products ADD COLUMN image TEXT');
          await _createProductGroups(d);
        }
      },
    );
  }

  Future<void> _createProductGroups(DatabaseExecutor executor) =>
      executor.execute('''CREATE TABLE product_groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        image TEXT,
        UNIQUE(category, name))''');

  Future<void> _createSpecialDays(Database d) => d.execute(
      '''CREATE TABLE special_days(
        date TEXT PRIMARY KEY,
        open INTEGER NOT NULL,
        note TEXT)''');

  // ---------- Histórico de 2 años (ventana móvil) ----------

  /// Borra lo anterior a hoy menos 2 años. Se llama al arrancar la app.
  Future<void> purgeOld() async {
    final cutoff = Schedule.fmt(Schedule.retentionLimit());
    final d = await db;
    await d.delete('consumption', where: 'date<?', whereArgs: [cutoff]);
    await d.delete('special_days', where: 'date<?', whereArgs: [cutoff]);
  }

  // ---------- Productos ----------

  Future<List<Product>> products() async {
    final rows = await (await db).query('products', orderBy: 'category, name');
    return rows.map(Product.fromMap).toList();
  }

  /// Grupos de variantes (categoría y nombre) existentes en la BD.
  Future<List<({String category, String name})>> productGroups() async {
    final rows =
        await (await db).query('product_groups', orderBy: 'category, name');
    return [
      for (final r in rows)
        (category: r['category'] as String, name: r['name'] as String),
    ];
  }

  Future<void> addProduct(
    Product p, {
    required String? groupImage,
  }) async {
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    final database = await db;
    await database.transaction((transaction) async {
      await transaction.insert('products', p.toMap());
      await _ensureProductGroup(transaction, p);
      if (groupImage != null) {
        await _saveProductGroupImage(
          transaction,
          category: p.category,
          name: p.groupName,
          image: groupImage,
        );
      }
    });
    _changed();
  }

  Future<void> updateProduct(
    Product p, {
    required String? groupImage,
  }) async {
    if (p.id == null) {
      throw ArgumentError.value(p.id, 'id', 'El producto debe tener un id.');
    }
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    final database = await db;
    await database.transaction((transaction) async {
      await transaction
          .update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
      await _ensureProductGroup(transaction, p);
      await _saveProductGroupImage(
        transaction,
        category: p.category,
        name: p.groupName,
        image: groupImage,
      );
    });
    _changed();
  }

  Future<void> _ensureProductGroup(
      DatabaseExecutor executor, Product product) async {
    final group = product.groupName?.trim();
    if (group == null || group.isEmpty) return;
    await executor.insert(
      'product_groups',
      {'category': product.category.trim(), 'name': group},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<String?> productGroupImage({
    required String category,
    required String name,
  }) async {
    final rows = await (await db).query(
      'product_groups',
      columns: ['image'],
      where: 'category = ? AND name = ?',
      whereArgs: [category.trim(), name.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['image'] as String?;
  }

  Future<void> setProductGroupImage({
    required String category,
    required String name,
    required String? image,
  }) async {
    if (category.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('La categoría y el nombre del grupo son obligatorios.');
    }
    final database = await db;
    await database.transaction((transaction) async {
      await _saveProductGroupImage(
        transaction,
        category: category,
        name: name,
        image: image,
      );
    });
    _changed();
  }

  Future<void> _saveProductGroupImage(
    DatabaseExecutor executor, {
    required String category,
    required String? name,
    required String? image,
  }) async {
    final normalizedCategory = category.trim();
    final normalizedName = name?.trim() ?? '';
    if (normalizedCategory.isEmpty || normalizedName.isEmpty) {
      return;
    }
    await executor.insert(
      'product_groups',
      {
        'category': normalizedCategory,
        'name': normalizedName,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final normalizedImage = image?.trim();
    await executor.update(
      'product_groups',
      {
        'image': normalizedImage == null || normalizedImage.isEmpty
            ? null
            : normalizedImage,
      },
      where: 'category = ? AND name = ?',
      whereArgs: [normalizedCategory, normalizedName],
    );
  }

  Future<void> deleteProduct(int id) async {
    final d = await db;
    await d.transaction((transaction) async {
      await transaction.delete(
        'consumption',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await transaction.delete('products', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  // ---------- Consumo ----------

  /// Guarda la lista de una noche (sustituye la que hubiera de esa fecha).
  /// Los productos no incluidos cuentan como consumo 0.
  Future<void> saveNight(String date, Map<int, int> qty) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('consumption', where: 'date=?', whereArgs: [date]);
      // Fila "marcador" (product_id 0) para saber que esa noche existió.
      await t.insert(
          'consumption', {'product_id': 0, 'date': date, 'quantity': 0});
      for (final e in qty.entries.where((e) => e.value > 0)) {
        await t.insert('consumption',
            {'product_id': e.key, 'date': date, 'quantity': e.value});
      }
    });
    _changed();
  }

  /// date -> (productId -> cantidad). Por defecto, todo el histórico.
  Future<Map<String, Map<int, int>>> nights([String? since]) async {
    final rows = await (await db).query('consumption',
        where: since == null ? null : 'date>=?',
        whereArgs: since == null ? null : [since]);
    final out = <String, Map<int, int>>{};
    for (final r in rows) {
      final m = out.putIfAbsent(r['date'] as String, () => {});
      final pid = r['product_id'] as int;
      if (pid != 0) m[pid] = r['quantity'] as int;
    }
    return out;
  }

  // ---------- Calendario de excepciones ----------

  Future<Map<String, SpecialDay>> specialDays() async {
    final rows = await (await db).query('special_days');
    return {
      for (final r in rows) r['date'] as String: SpecialDay.fromMap(r),
    };
  }

  Future<void> setSpecialDay(SpecialDay s) async {
    await (await db).insert(
        'special_days', {'date': s.date, 'open': s.open ? 1 : 0, 'note': s.note},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _changed();
  }

  Future<void> deleteSpecialDay(String date) async {
    await (await db).delete('special_days', where: 'date=?', whereArgs: [date]);
    _changed();
  }
}
