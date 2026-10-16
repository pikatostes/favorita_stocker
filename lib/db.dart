import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'schedule.dart';

/// Acceso a SQLite (esquema v8, tablas en inglés singular).
///
/// Normaliza el catálogo: `category`, `product_group`, `subcategory` y `box`
/// son entidades propias; `product` solo guarda referencias. El consumo vive en
/// `consumption` (una fila por producto y noche) y `night` marca qué noches
/// existen. Los productos se borran de forma lógica (`deleted_at`).
class Db {
  Db._();
  static final Db i = Db._();
  Database? _db;

  /// Versión del esquema. Cualquier cambio estructural sube este número.
  static const int schemaVersion = 10;

  /// Se incrementa con cada escritura; las pantallas escuchan para refrescarse.
  final ValueNotifier<int> version = ValueNotifier(0);
  void _changed() => version.value++;

  static int get _nowMs => DateTime.now().millisecondsSinceEpoch;
  int get _now => _nowMs;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'stock_bar.db');
    return openAt(path);
  }

  /// Abre (creando o migrando) una base de datos en [path] con el esquema actual.
  /// Expuesto para poder probar la creación y la migración con una BD temporal.
  @visibleForTesting
  static Future<Database> openAt(String path) => openDatabase(
        path,
        version: schemaVersion,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) => _createV8(d),
        onUpgrade: _onUpgrade,
      );

  static Future<void> _onUpgrade(Database d, int oldV, int newV) async {
    // Migraciones antiguas (esquema desnormalizado)...
    if (oldV < 2) await _legacyCreateSpecialDays(d);
    if (oldV < 3) {
      await d.execute(
          "ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT 'Otros'");
      await d.execute(
          'ALTER TABLE products ADD COLUMN size REAL NOT NULL DEFAULT 1');
      await d.execute(
          'ALTER TABLE products ADD COLUMN height REAL NOT NULL DEFAULT 1');
      await d.execute(
          'ALTER TABLE products ADD COLUMN format INTEGER NOT NULL DEFAULT 1');
    }
    if (oldV < 4) {
      await d.execute(
          "ALTER TABLE products ADD COLUMN crate_name TEXT NOT NULL DEFAULT ''");
      await d.execute(
          'ALTER TABLE products ADD COLUMN trip_capacity INTEGER NOT NULL DEFAULT 5');
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
      await d.execute('''CREATE TABLE product_groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        image TEXT,
        UNIQUE(category, name))''');
    }
    // ...y por último la normalización a v8.
    if (oldV < 8) await _migrateToV8(d);
    // ...y la reparación de grupos históricos de variantes a v9.
    if (oldV < 9) await _repairLegacyVariantGroups(d);
    // ...y la agrupación de cervezas por marca a v10.
    if (oldV < 10) await _regroupBeers(d);
  }

  // ---------------------------------------------------------------------------
  // Esquema
  // ---------------------------------------------------------------------------

  static Future<void> _createV8(DatabaseExecutor d) async {
    await d.execute('''CREATE TABLE category(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE)''');
    await d.execute('''CREATE TABLE box(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL UNIQUE,
      units_per_box INTEGER NOT NULL DEFAULT 24 CHECK(units_per_box > 0),
      size REAL NOT NULL DEFAULT 1 CHECK(size > 0),
      height REAL NOT NULL DEFAULT 1 CHECK(height > 0),
      width REAL NOT NULL DEFAULT 1 CHECK(width > 0),
      format INTEGER NOT NULL DEFAULT 1 CHECK(format > 0),
      trip_capacity INTEGER NOT NULL DEFAULT 5 CHECK(trip_capacity > 0),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL)''');
    await d.execute('''CREATE TABLE product_group(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER NOT NULL REFERENCES category(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      image TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(category_id, name))''');
    await d.execute('''CREATE TABLE subcategory(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL REFERENCES product_group(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      UNIQUE(group_id, name))''');
    await d.execute('''CREATE TABLE product(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      box_id INTEGER NOT NULL REFERENCES box(id),
      group_id INTEGER NOT NULL REFERENCES product_group(id),
      subcategory_id INTEGER REFERENCES subcategory(id),
      image TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER)''');
    await d.execute('''CREATE TABLE night(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      note TEXT,
      created_at INTEGER NOT NULL)''');
    await d.execute('''CREATE TABLE consumption(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      night_id INTEGER NOT NULL REFERENCES night(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES product(id),
      quantity INTEGER NOT NULL CHECK(quantity >= 0),
      UNIQUE(night_id, product_id))''');
    await d.execute('''CREATE TABLE special_day(
      date TEXT PRIMARY KEY,
      open INTEGER NOT NULL CHECK(open IN (0, 1)),
      note TEXT)''');
    await d.execute('''CREATE TABLE app_metadata(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL)''');

    await d.execute('CREATE INDEX idx_product_group ON product(group_id)');
    await d.execute('CREATE INDEX idx_product_box ON product(box_id)');
    await d.execute(
        'CREATE INDEX idx_product_subcategory ON product(subcategory_id)');
    await d.execute('CREATE INDEX idx_product_deleted ON product(deleted_at)');
    await d.execute(
        'CREATE INDEX idx_group_category ON product_group(category_id)');
    await d.execute(
        'CREATE INDEX idx_subcategory_group ON subcategory(group_id)');
    await d
        .execute('CREATE INDEX idx_consumption_product ON consumption(product_id)');
    await d.execute('CREATE INDEX idx_consumption_night ON consumption(night_id)');
  }

  static Future<void> _legacyCreateSpecialDays(DatabaseExecutor d) => d.execute(
      '''CREATE TABLE special_days(
        date TEXT PRIMARY KEY,
        open INTEGER NOT NULL,
        note TEXT)''');

  /// Reconstruye la BD pasando del esquema desnormalizado (v7) al normalizado.
  ///
  /// Se leen los datos antiguos, se recrean las tablas y se vuelcan mapeando el
  /// texto a claves foráneas. Los productos sin grupo reciben un grupo propio
  /// con su nombre (el grupo es obligatorio) y los productos sin tipo de caja
  /// pasan a llamarse "Caja".
  static Future<void> _migrateToV8(Database d) async {
    final oldProducts = await d.rawQuery('SELECT * FROM products');
    final oldGroups = await d.rawQuery('SELECT * FROM product_groups');
    final oldConsumption = await d.rawQuery('SELECT * FROM consumption');
    final oldSpecial = await d.rawQuery('SELECT * FROM special_days');
    final oldMeta = await d.rawQuery('SELECT * FROM app_metadata');

    // Borrar tablas antiguas (de hijo a padre para respetar las FK).
    for (final table in [
      'consumption',
      'night',
      'product',
      'subcategory',
      'product_group',
      'box',
      'category',
      'special_days',
      'product_groups',
      'app_metadata',
      'products',
    ]) {
      await d.execute('DROP TABLE IF EXISTS $table');
    }

    await _createV8(d);

    final now = DateTime.now().millisecondsSinceEpoch;
    final catIds = <String, int>{};
    final groupIds = <String, int>{};
    final subIds = <String, int>{};
    final boxIds = <String, int>{}; // firma de atributos -> id
    final boxNameCount = <String, int>{};
    final productIds = <int, int>{}; // id antiguo -> id nuevo

    String norm(String? s, String fallback) {
      final t = s?.trim() ?? '';
      return t.isEmpty ? fallback : t;
    }

    Future<int> ensureCategory(String name) async {
      final n = norm(name, 'Otros');
      final existing = catIds[n];
      if (existing != null) return existing;
      final id = await d.insert('category', {'name': n});
      catIds[n] = id;
      return id;
    }

    Future<int> ensureGroup(int categoryId, String name, {String? image}) async {
      final n = norm(name, 'General');
      final key = '$categoryId\u0000$n';
      final existing = groupIds[key];
      final img = image?.trim();
      if (existing != null) {
        if (img != null && img.isNotEmpty) {
          await d.update('product_group', {'image': img, 'updated_at': now},
              where: 'id = ?', whereArgs: [existing]);
        }
        return existing;
      }
      final id = await d.insert('product_group', {
        'category_id': categoryId,
        'name': n,
        'image': (img == null || img.isEmpty) ? null : img,
        'created_at': now,
        'updated_at': now,
      });
      groupIds[key] = id;
      return id;
    }

    Future<int?> ensureSub(int groupId, String? name) async {
      final n = name?.trim() ?? '';
      if (n.isEmpty) return null;
      final key = '$groupId\u0000$n';
      final existing = subIds[key];
      if (existing != null) return existing;
      final id = await d.insert('subcategory', {'group_id': groupId, 'name': n});
      subIds[key] = id;
      return id;
    }

    Future<int> ensureBox(String type, int units, double size, double height,
        double width, int format, int trip) async {
      final name = norm(type, 'Caja');
      final u = units < 1 ? 1 : units;
      final s = size.isFinite && size > 0 ? size : 1.0;
      final h = height.isFinite && height > 0 ? height : 1.0;
      final w = width.isFinite && width > 0 ? width : 1.0;
      final f = format < 1 ? 1 : format;
      final t = trip < 1 ? 1 : trip;
      final signature = '$name|$u|$s|$h|$w|$f|$t';
      final existing = boxIds[signature];
      if (existing != null) return existing;
      // Un mismo tipo con atributos distintos no puede repetirse (UNIQUE type):
      // se le añade un sufijo para no perder los datos.
      var finalName = name;
      final count = boxNameCount[name] ?? 0;
      if (count > 0) finalName = '$name (${count + 1})';
      boxNameCount[name] = count + 1;
      final id = await d.insert('box', {
        'type': finalName,
        'units_per_box': u,
        'size': s,
        'height': h,
        'width': w,
        'format': f,
        'trip_capacity': t,
        'created_at': now,
        'updated_at': now,
      });
      boxIds[signature] = id;
      return id;
    }

    // Grupos (y sus imágenes) primero.
    for (final g in oldGroups) {
      final catId = await ensureCategory((g['category'] as String?) ?? 'Otros');
      await ensureGroup(catId, (g['name'] as String?) ?? '',
          image: g['image'] as String?);
    }

    for (final p in oldProducts) {
      final oldId = p['id'] as int;
      final catId = await ensureCategory((p['category'] as String?) ?? 'Otros');
      final groupName =
          norm(p['group_name'] as String?, norm(p['name'] as String?, 'General'));
      final groupId = await ensureGroup(catId, groupName);
      final subId = await ensureSub(groupId, p['subcategory'] as String?);
      final boxId = await ensureBox(
        (p['crate_name'] as String?) ?? '',
        (p['units_per_box'] as int?) ?? 24,
        ((p['size'] as num?) ?? 1).toDouble(),
        ((p['height'] as num?) ?? 1).toDouble(),
        1.0,
        (p['format'] as int?) ?? 1,
        (p['trip_capacity'] as int?) ?? 5,
      );
      final newId = await d.insert('product', {
        'name': (p['name'] as String?) ?? '',
        'box_id': boxId,
        'group_id': groupId,
        'subcategory_id': subId,
        'image': p['image'] as String?,
        'created_at': now,
        'updated_at': now,
      });
      productIds[oldId] = newId;
    }

    // Noches (una por fecha) y consumo.
    final nightIds = <String, int>{};
    for (final c in oldConsumption) {
      nightIds[c['date'] as String] = 0;
    }
    for (final date in nightIds.keys.toList()) {
      nightIds[date] = await d.insert('night', {'date': date, 'created_at': now});
    }
    for (final c in oldConsumption) {
      final oldPid = c['product_id'] as int;
      if (oldPid == 0) continue; // fila marcador antigua
      final newPid = productIds[oldPid];
      if (newPid == null) continue; // producto ya inexistente
      await d.insert('consumption', {
        'night_id': nightIds[c['date'] as String]!,
        'product_id': newPid,
        'quantity': (c['quantity'] as int?) ?? 0,
      });
    }

    for (final s in oldSpecial) {
      await d.insert(
          'special_day',
          {
            'date': s['date'] as String,
            'open': (s['open'] as int?) ?? 0,
            'note': s['note'] as String?,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final m in oldMeta) {
      await d.insert(
          'app_metadata',
          {'key': m['key'] as String, 'value': (m['value'] as String?) ?? ''},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Nombres históricos de variantes que quedaron con un grupo propio.
  ///
  /// En versiones antiguas algunos productos se llamaban distinto que en el
  /// catálogo actual (p. ej. "Aquarius Naranja", "Tónica Bliss", "Ginger Ale").
  /// Como no tenían grupo, la normalización a v8 les creó uno con su propio
  /// nombre y nunca se juntaron con sus variantes.
  static const Map<String, ({String group, String subcategory})>
      _legacyVariantGroups = {
    'Aquarius Naranja': (group: 'Aquarius', subcategory: 'Naranja'),
    'Tónica Bliss': (group: 'Bliss', subcategory: 'Tónica'),
    'Ginger Ale': (group: 'Bliss', subcategory: 'Ginger Ale'),
  };

  /// Reasigna esos productos a su grupo de variantes y borra los grupos huérfanos.
  /// Es idempotente: si ya están bien, no hace nada.
  static Future<void> _repairLegacyVariantGroups(Database d) async {
    final now = _nowMs;
    for (final entry in _legacyVariantGroups.entries) {
      final rows = await d.rawQuery('''
        SELECT p.id AS id, p.group_id AS old_group_id,
               g.category_id AS category_id
        FROM product p
        JOIN product_group g ON g.id = p.group_id
        WHERE p.name = ? AND p.deleted_at IS NULL''', [entry.key]);
      for (final row in rows) {
        final groupId = await _ensureGroup(
          d,
          categoryId: row['category_id'] as int,
          name: entry.value.group,
        );
        final subId = await _ensureSubcategory(
          d,
          groupId: groupId,
          name: entry.value.subcategory,
        );
        await d.update(
          'product',
          {'group_id': groupId, 'subcategory_id': subId, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        final oldGroupId = row['old_group_id'] as int;
        if (oldGroupId != groupId) {
          final remaining = Sqflite.firstIntValue(await d.rawQuery(
              'SELECT COUNT(*) FROM product WHERE group_id = ?',
              [oldGroupId]));
          if (remaining == 0) {
            await d.delete('product_group',
                where: 'id = ?', whereArgs: [oldGroupId]);
          }
        }
      }
    }
  }

  /// Marca y subcategoría de las cervezas que no van a "Otros".
  static const Map<String, ({String group, String subcategory})> _beerGroups = {
    'Cruzcampo': (group: 'Cruzcampo', subcategory: 'Pilsen'),
    '1904': (group: 'Cruzcampo', subcategory: '1904'),
    'Cruzcampo Gran Reserva': (group: 'Cruzcampo', subcategory: 'Gran Reserva'),
    'Cruzcampo Radler': (group: 'Cruzcampo', subcategory: 'Radler'),
    'Heineken': (group: 'Heineken', subcategory: 'Normal'),
    'Heineken 0,0': (group: 'Heineken', subcategory: '0,0'),
  };

  /// Reagrupa las cervezas por marca (v10).
  ///
  /// Antes cada cerveza tenía su propio grupo (su nombre). Ahora se juntan bajo
  /// Cruzcampo, Heineken u "Otros"; el resto de cervezas de la categoría caen en
  /// "Otros" con su nombre como subcategoría. Borra los grupos que quedan vacíos.
  static Future<void> _regroupBeers(Database d) async {
    final now = _nowMs;
    final rows = await d.rawQuery('''
      SELECT p.id AS id, p.name AS name, g.category_id AS category_id
      FROM product p
      JOIN product_group g ON g.id = p.group_id
      JOIN category c ON c.id = g.category_id
      WHERE p.deleted_at IS NULL AND c.name = 'Cervezas y similares' ''');
    if (rows.isEmpty) return;

    final groupIds = <String, int>{};
    for (final row in rows) {
      final categoryId = row['category_id'] as int;
      final name = row['name'] as String;
      final spec = _beerGroups[name];
      final groupName = spec?.group ?? 'Otros';
      final subName = spec?.subcategory ?? name;
      final key = '$categoryId\u0000$groupName';
      final groupId = groupIds[key] ??= await _ensureGroup(
        d,
        categoryId: categoryId,
        name: groupName,
      );
      final subId = await _ensureSubcategory(
        d,
        groupId: groupId,
        name: subName,
      );
      await d.update(
        'product',
        {'group_id': groupId, 'subcategory_id': subId, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    // Borra los grupos de cerveza que han quedado vacíos (p. ej. "Sol").
    await d.delete(
      'product_group',
      where: 'category_id IN (SELECT id FROM category WHERE name = ?) '
          'AND id NOT IN (SELECT group_id FROM product)',
      whereArgs: ['Cervezas y similares'],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de catálogo (resuelven/crean entidades por nombre)
  // ---------------------------------------------------------------------------

  static Future<int> _ensureCategory(DatabaseExecutor t, String name) async {
    final n = name.trim().isEmpty ? 'Otros' : name.trim();
    final rows = await t.query('category',
        columns: ['id'], where: 'name = ?', whereArgs: [n], limit: 1);
    if (rows.isNotEmpty) return rows.single['id'] as int;
    return t.insert('category', {'name': n});
  }

  static Future<int> _ensureGroup(
    DatabaseExecutor t, {
    required int categoryId,
    required String name,
  }) async {
    final n = name.trim();
    final rows = await t.query('product_group',
        columns: ['id'],
        where: 'category_id = ? AND name = ?',
        whereArgs: [categoryId, n],
        limit: 1);
    if (rows.isNotEmpty) return rows.single['id'] as int;
    final now = _nowMs;
    return t.insert('product_group', {
      'category_id': categoryId,
      'name': n,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<int?> _ensureSubcategory(
    DatabaseExecutor t, {
    required int groupId,
    String? name,
  }) async {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return null;
    final rows = await t.query('subcategory',
        columns: ['id'],
        where: 'group_id = ? AND name = ?',
        whereArgs: [groupId, n],
        limit: 1);
    if (rows.isNotEmpty) return rows.single['id'] as int;
    return t.insert('subcategory', {'group_id': groupId, 'name': n});
  }

  static Future<int> _upsertBox(DatabaseExecutor t, CrateType box) async {
    final type = box.name.trim().isEmpty ? 'Caja' : box.name.trim();
    final now = _nowMs;
    final columns = {
      'units_per_box': box.units < 1 ? 1 : box.units,
      'size': box.size.isFinite && box.size > 0 ? box.size : 1.0,
      'height': box.height.isFinite && box.height > 0 ? box.height : 1.0,
      'width': box.width.isFinite && box.width > 0 ? box.width : 1.0,
      'format': box.format < 1 ? 1 : box.format,
      'trip_capacity': box.trip < 1 ? 1 : box.trip,
      'updated_at': now,
    };
    final rows = await t.query('box',
        columns: ['id'], where: 'type = ?', whereArgs: [type], limit: 1);
    if (rows.isNotEmpty) {
      final id = rows.single['id'] as int;
      await t.update('box', columns, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return t.insert('box', {'type': type, 'created_at': now, ...columns});
  }

  Future<void> _saveGroupImage(
      DatabaseExecutor t, int groupId, String? image) async {
    final n = image?.trim();
    await t.update(
      'product_group',
      {'image': (n == null || n.isEmpty) ? null : n, 'updated_at': _now},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  // ---------------------------------------------------------------------------
  // Histórico de 2 años (ventana móvil)
  // ---------------------------------------------------------------------------

  /// Borra lo anterior a hoy menos 2 años. Se llama al arrancar la app.
  Future<void> purgeOld() async {
    final cutoff = Schedule.fmt(Schedule.retentionLimit());
    final d = await db;
    await d.transaction((t) async {
      await t.delete('consumption',
          where: 'night_id IN (SELECT id FROM night WHERE date < ?)',
          whereArgs: [cutoff]);
      await t.delete('night', where: 'date < ?', whereArgs: [cutoff]);
      await t.delete('special_day', where: 'date < ?', whereArgs: [cutoff]);
    });
  }

  // ---------------------------------------------------------------------------
  // Productos
  // ---------------------------------------------------------------------------

  static const String _productSelect = '''
    SELECT p.id, p.name, p.image, p.deleted_at,
           c.name AS category,
           g.name AS group_name,
           s.name AS subcategory,
           b.type AS box_name, b.units_per_box, b.size, b.height, b.width,
           b.format, b.trip_capacity
    FROM product p
    JOIN product_group g ON g.id = p.group_id
    JOIN category c ON c.id = g.category_id
    LEFT JOIN subcategory s ON s.id = p.subcategory_id
    JOIN box b ON b.id = p.box_id''';

  /// Productos vivos (o todos, con [includeDeleted]) con su grupo y caja.
  Future<List<Product>> products({bool includeDeleted = false}) async {
    final rows = await (await db).rawQuery(
      '$_productSelect ${includeDeleted ? '' : 'WHERE p.deleted_at IS NULL'} '
      'ORDER BY c.name, p.name',
    );
    return rows.map(Product.fromRow).toList();
  }

  /// Categorías existentes.
  Future<List<String>> categories() async {
    final rows =
        await (await db).query('category', columns: ['name'], orderBy: 'name');
    return [for (final r in rows) r['name'] as String];
  }

  /// Tipos de caja existentes (tabla `box`).
  Future<List<CrateType>> boxTypes() async {
    final rows = await (await db).query('box', orderBy: 'type');
    return [
      for (final r in rows)
        CrateType(
          r['type'] as String,
          r['units_per_box'] as int,
          ((r['size'] as num?) ?? 1).toDouble(),
          ((r['height'] as num?) ?? 1).toDouble(),
          (r['format'] as int?) ?? 1,
          (r['trip_capacity'] as int?) ?? 5,
          width: ((r['width'] as num?) ?? 1).toDouble(),
          id: r['id'] as int,
        ),
    ];
  }

  /// Grupos de variantes (categoría y nombre) existentes en la BD.
  Future<List<({String category, String name})>> productGroups() async {
    final rows = await (await db).rawQuery('''
      SELECT c.name AS category, g.name AS name
      FROM product_group g
      JOIN category c ON c.id = g.category_id
      ORDER BY c.name, g.name''');
    return [
      for (final r in rows)
        (category: r['category'] as String, name: r['name'] as String),
    ];
  }

  /// Subcategorías con su categoría y grupo.
  Future<List<({String category, String group, String name})>>
      subcategories() async {
    final rows = await (await db).rawQuery('''
      SELECT c.name AS category, g.name AS grp, s.name AS name
      FROM subcategory s
      JOIN product_group g ON g.id = s.group_id
      JOIN category c ON c.id = g.category_id
      ORDER BY c.name, g.name, s.name''');
    return [
      for (final r in rows)
        (
          category: r['category'] as String,
          group: r['grp'] as String,
          name: r['name'] as String,
        ),
    ];
  }

  Future<void> addProduct(Product p, {required String? groupImage}) async {
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    final database = await db;
    await database.transaction((t) async {
      final now = _now;
      final categoryId = await _ensureCategory(t, p.category);
      final groupId =
          await _ensureGroup(t, categoryId: categoryId, name: p.groupName!);
      final subcategoryId =
          await _ensureSubcategory(t, groupId: groupId, name: p.subcategory);
      final boxId = await _upsertBox(t, p.box);
      await t.insert('product', {
        'name': p.name.trim(),
        'box_id': boxId,
        'group_id': groupId,
        'subcategory_id': subcategoryId,
        'image': p.image,
        'created_at': now,
        'updated_at': now,
      });
      if (groupImage != null) await _saveGroupImage(t, groupId, groupImage);
    });
    _changed();
  }

  Future<void> updateProduct(Product p, {required String? groupImage}) async {
    if (p.id == null) {
      throw ArgumentError.value(p.id, 'id', 'El producto debe tener un id.');
    }
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    final database = await db;
    await database.transaction((t) async {
      final categoryId = await _ensureCategory(t, p.category);
      final groupId =
          await _ensureGroup(t, categoryId: categoryId, name: p.groupName!);
      final subcategoryId =
          await _ensureSubcategory(t, groupId: groupId, name: p.subcategory);
      final boxId = await _upsertBox(t, p.box);
      await t.update(
        'product',
        {
          'name': p.name.trim(),
          'box_id': boxId,
          'group_id': groupId,
          'subcategory_id': subcategoryId,
          'image': p.image,
          'updated_at': _now,
        },
        where: 'id = ?',
        whereArgs: [p.id],
      );
      if (groupImage != null) await _saveGroupImage(t, groupId, groupImage);
    });
    _changed();
  }

  Future<String?> productGroupImage({
    required String category,
    required String name,
  }) async {
    final rows = await (await db).rawQuery('''
      SELECT g.image
      FROM product_group g
      JOIN category c ON c.id = g.category_id
      WHERE c.name = ? AND g.name = ?
      LIMIT 1''', [category.trim(), name.trim()]);
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
    await database.transaction((t) async {
      final categoryId = await _ensureCategory(t, category);
      final groupId = await _ensureGroup(t, categoryId: categoryId, name: name);
      await _saveGroupImage(t, groupId, image);
    });
    _changed();
  }

  /// Borrado lógico: el producto deja de mostrarse pero se conserva el histórico.
  Future<void> deleteProduct(int id) async {
    final now = _now;
    await (await db).update(
      'product',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Consumo
  // ---------------------------------------------------------------------------

  /// Guarda la lista de una noche (sustituye la que hubiera de esa fecha).
  /// Los productos no incluidos cuentan como consumo 0.
  Future<void> saveNight(String date, Map<int, int> qty) async {
    final d = await db;
    await d.transaction((t) async {
      final existing = await t.query('night',
          columns: ['id'], where: 'date = ?', whereArgs: [date], limit: 1);
      final nightId = existing.isNotEmpty
          ? existing.single['id'] as int
          : await t.insert('night', {'date': date, 'created_at': _now});
      await t.delete('consumption',
          where: 'night_id = ?', whereArgs: [nightId]);
      for (final e in qty.entries.where((e) => e.value > 0)) {
        await t.insert('consumption', {
          'night_id': nightId,
          'product_id': e.key,
          'quantity': e.value,
        });
      }
    });
    _changed();
  }

  /// date -> (productId -> cantidad). Por defecto, todo el histórico.
  Future<Map<String, Map<int, int>>> nights([String? since]) async {
    final rows = await (await db).rawQuery(
      'SELECT n.date AS date, c.product_id AS product_id, c.quantity AS quantity '
      'FROM consumption c JOIN night n ON n.id = c.night_id '
      '${since == null ? '' : 'WHERE n.date >= ?'}',
      since == null ? null : [since],
    );
    final out = <String, Map<int, int>>{};
    for (final r in rows) {
      out.putIfAbsent(r['date'] as String, () => {})[r['product_id'] as int] =
          r['quantity'] as int;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Calendario de excepciones
  // ---------------------------------------------------------------------------

  Future<Map<String, SpecialDay>> specialDays() async {
    final rows = await (await db).query('special_day');
    return {
      for (final r in rows) r['date'] as String: SpecialDay.fromMap(r),
    };
  }

  Future<void> setSpecialDay(SpecialDay s) async {
    await (await db).insert(
      'special_day',
      {'date': s.date, 'open': s.open ? 1 : 0, 'note': s.note},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changed();
  }

  Future<void> deleteSpecialDay(String date) async {
    await (await db).delete('special_day', where: 'date = ?', whereArgs: [date]);
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Semilla
  // ---------------------------------------------------------------------------

  /// Inserta el catálogo inicial si la tabla `product` está vacía.
  Future<void> seedCatalog(List<Product> products) async {
    final database = await db;
    await database.transaction((t) async {
      final count =
          (await t.rawQuery('SELECT COUNT(*) AS c FROM product')).single['c']
              as int;
      if (count > 0) return;
      final now = _now;
      for (final p in products) {
        final categoryId = await _ensureCategory(t, p.category);
        final groupId = await _ensureGroup(t,
            categoryId: categoryId, name: p.groupName ?? p.name);
        final subcategoryId =
            await _ensureSubcategory(t, groupId: groupId, name: p.subcategory);
        final boxId = await _upsertBox(t, p.box);
        await t.insert('product', {
          'name': p.name.trim(),
          'box_id': boxId,
          'group_id': groupId,
          'subcategory_id': subcategoryId,
          'image': p.image,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    _changed();
  }
}
