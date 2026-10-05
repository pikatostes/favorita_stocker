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
      version: 4,
      onCreate: (d, _) async {
        await d.execute('''CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Otros',
          units_per_box INTEGER NOT NULL DEFAULT 24,
          size REAL NOT NULL DEFAULT 1,
          height REAL NOT NULL DEFAULT 1,
          format INTEGER NOT NULL DEFAULT 1,
          crate_name TEXT NOT NULL DEFAULT '',
          trip_capacity INTEGER NOT NULL DEFAULT 5)''');
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
          // Rellena los productos iniciales ya existentes según su tipo de caja.
          Future<void> tag(double s, double h, int f, String n, int trip) =>
              d.execute(
                  'UPDATE products SET crate_name=?, trip_capacity=? WHERE size=? AND height=? AND format=?',
                  [n, trip, s, h, f]);
          await tag(1, 0.5, 1, 'Cola', 6);
          await tag(1, 1, 1, 'Nestea', 5);
          await tag(1, 2, 1, 'Nestea alto', 5);
          await tag(1, 1, 2, 'Cerveza', 5);
          await tag(2, 1, 2, 'Cerveza grande', 5);
          await tag(2, 1, 3, 'Agua', 5);
        }
      },
    );
  }

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

  Future<void> addProduct(Product p) async {
    await (await db).insert('products', p.toMap());
    _changed();
  }

  Future<void> updateProduct(Product p) async {
    await (await db)
        .update('products', p.toMap(), where: 'id=?', whereArgs: [p.id]);
    _changed();
  }

  /// Carga los productos iniciales solo si la tabla está vacía.
  Future<void> seedIfEmpty(List<Product> initial) async {
    final d = await db;
    final n = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM products'));
    if ((n ?? 0) > 0) return;
    final b = d.batch();
    for (final p in initial) {
      b.insert('products', p.toMap());
    }
    await b.commit(noResult: true);
    _changed();
  }

  Future<void> deleteProduct(int id) async {
    final d = await db;
    await d.delete('products', where: 'id=?', whereArgs: [id]);
    await d.delete('consumption', where: 'product_id=?', whereArgs: [id]);
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
