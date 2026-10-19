import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_bar/db.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/shifts.dart';

/// Crea el esquema desnormalizado v7 con datos de ejemplo.
Future<void> _createLegacyV7(Database d) async {
  await d.execute('''CREATE TABLE products(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Otros',
    size REAL NOT NULL DEFAULT 1,
    height REAL NOT NULL DEFAULT 1,
    format INTEGER NOT NULL DEFAULT 1,
    crate_name TEXT NOT NULL DEFAULT '',
    trip_capacity INTEGER NOT NULL DEFAULT 5,
    group_name TEXT,
    subcategory TEXT,
    image TEXT,
    units_per_box INTEGER NOT NULL DEFAULT 24)''');
  await d.execute('''CREATE TABLE product_groups(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    image TEXT,
    UNIQUE(category, name))''');
  await d.execute('''CREATE TABLE app_metadata(
    key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
  await d.execute('''CREATE TABLE consumption(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    date TEXT NOT NULL,
    quantity INTEGER NOT NULL)''');
  await d.execute('''CREATE TABLE special_days(
    date TEXT PRIMARY KEY, open INTEGER NOT NULL, note TEXT)''');

  await d.insert('products', {
    'name': 'Coca-Cola',
    'category': 'Refrescos y zumos',
    'size': 1.0,
    'height': 0.5,
    'format': 1,
    'crate_name': 'Cola',
    'trip_capacity': 6,
    'group_name': 'Coca-Cola',
    'subcategory': 'Original',
    'units_per_box': 24,
  });
  await d.insert('products', {
    'name': 'Cruzcampo',
    'category': 'Cervezas y similares',
    'size': 1.0,
    'height': 1.0,
    'format': 2,
    'crate_name': 'Cerveza',
    'trip_capacity': 5,
    'units_per_box': 24,
  });
  await d.insert(
      'product_groups', {'category': 'Refrescos y zumos', 'name': 'Coca-Cola'});
  await d.insert(
      'consumption', {'product_id': 1, 'date': '2026-01-03', 'quantity': 12});
  await d.insert('consumption', {
    'product_id': 0,
    'date': '2026-01-03',
    'quantity': 0
  }); // marcador antiguo
  await d.insert(
      'special_days', {'date': '2026-01-03', 'open': 1, 'note': 'prueba'});
  await d.insert('app_metadata', {'key': 'legacy', 'value': 'v1'});
}

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => dir = Directory.systemTemp.createTempSync('stock_bar_test'));

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('crea el esquema actual en una base de datos nueva', () async {
    final d = await Db.openAt(p.join(dir.path, 'fresh.db'));
    addTearDown(d.close);

    final tables = (await d
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(
      tables,
      containsAll([
        'category',
        'box',
        'product_group',
        'subcategory',
        'product',
        'night',
        'consumption',
        'special_day',
        'app_metadata',
        'role',
        'employee',
        'shift',
      ]),
    );
    expect((await d.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);

    final employeeCols = (await d.rawQuery('PRAGMA table_info(employee)'))
        .map((r) => r['name'])
        .toSet();
    expect(employeeCols, containsAll(['opener', 'working_days']));
  });

  test('migra una base v7 al esquema normalizado v8', () async {
    final path = p.join(dir.path, 'legacy.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (d, _) => _createLegacyV7(d),
      ),
    );
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    final products = await d.rawQuery('''
      SELECT p.name AS name, c.name AS category, g.name AS grp,
             s.name AS sub, b.type AS box
      FROM product p
      JOIN product_group g ON g.id = p.group_id
      JOIN category c ON c.id = g.category_id
      LEFT JOIN subcategory s ON s.id = p.subcategory_id
      JOIN box b ON b.id = p.box_id
      ORDER BY p.name''');
    expect(products.length, 2);

    final cola = products.firstWhere((r) => r['name'] == 'Coca-Cola');
    expect(cola['category'], 'Refrescos y zumos');
    expect(cola['grp'], 'Coca-Cola');
    expect(cola['sub'], 'Original');
    expect(cola['box'], 'Cola');

    final cruz = products.firstWhere((r) => r['name'] == 'Cruzcampo');
    // Sin grupo en el esquema antiguo se creó uno con su nombre; la migración
    // v10 lo deja además en el grupo de marca "Cruzcampo" (subcategoría Pilsen).
    expect(cruz['grp'], 'Cruzcampo');
    expect(cruz['sub'], 'Pilsen');
    expect(cruz['box'], 'Cerveza');

    // Una sola noche y una sola fila de consumo (el marcador no se migra).
    expect((await d.query('night')).single['date'], '2026-01-03');
    final consumption = await d.query('consumption');
    expect(consumption.length, 1);
    expect(consumption.single['quantity'], 12);

    expect((await d.query('special_day')).length, 1);
    expect((await d.query('app_metadata')).single['value'], 'v1');

    // v12: la migración también crea las tablas de turnos.
    final tables = (await d
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, containsAll(['role', 'employee', 'shift']));
  });

  test('guarda puestos, empleados y turnos', () async {
    final d = await Db.openAt(p.join(dir.path, 'turnos.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    await Db.i.addRole(
      const JobRole(
        name: 'Karaoke',
        floor: Floor.karaoke,
        note: 'Evento privado',
      ),
    );
    final roles = await Db.i.roles();
    expect(roles.single.name, 'Karaoke');
    expect(roles.single.floor, Floor.karaoke);
    await expectLater(
      Db.i.addRole(const JobRole(name: 'Karaoke')),
      throwsA(isA<StateError>()),
    );

    await Db.i.addEmployee(
        Employee(name: 'Ana', role: roles.single, opener: true));
    final employees = await Db.i.employees();
    expect(employees.single.name, 'Ana');
    expect(employees.single.role.floor, Floor.karaoke);

    final generated = ShiftGenerator.generateMonth(
      month: DateTime(2026, 10),
      employees: employees,
      specialDays: const {},
    );
    expect(generated, isNotEmpty);
    await Db.i.replaceMonthShifts(DateTime(2026, 10), generated);

    final shifts = await Db.i.shiftsForMonth(DateTime(2026, 10));
    expect(shifts.length, generated.length);
    expect(shifts.first.note, 'Evento privado');
    expect(shifts.first.status, ShiftStatus.draft);

    await Db.i.publishMonth(DateTime(2026, 10));
    final published = await Db.i.shiftsForMonth(DateTime(2026, 10));
    expect(
      published.every((s) => s.status == ShiftStatus.published),
      isTrue,
    );

    final first = published.first;
    await Db.i.updateShift(first.copyWith(
      startMin: 16 * 60,
      endMin: 21 * 60,
      breakMin: 0,
      status: ShiftStatus.confirmed,
    ));
    final edited = (await Db.i.shiftsForMonth(DateTime(2026, 10)))
        .firstWhere((s) => s.id == first.id);
    expect(edited.status, ShiftStatus.confirmed);
    expect(edited.startMin, 16 * 60);
    expect(edited.breakMin, 0);

    await Db.i.deleteShift(first.id!);
    expect(
      (await Db.i.shiftsForMonth(DateTime(2026, 10))).length,
      published.length - 1,
    );

    await Db.i.setEmployeeActive(employees.single.id!, false);
    expect(await Db.i.employees(), isEmpty);
    expect((await Db.i.employees(includeInactive: true)).length, 1);

    expect(
      () => Db.i.deleteRole(roles.single.id!),
      throwsStateError,
    );
  });

  test('guarda la marca de apertura y los días del empleado', () async {
    final d = await Db.openAt(p.join(dir.path, 'empleados.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    await Db.i.addRole(const JobRole(name: 'Sala', floor: Floor.plantaBaja));
    final role = (await Db.i.roles()).single;
    await Db.i.addEmployee(Employee(
      name: 'Ana',
      role: role,
      opener: true,
      workingDays: const {DateTime.friday, DateTime.saturday},
    ));

    final saved = (await Db.i.employees()).single;
    expect(saved.opener, isTrue);
    expect(saved.workingDays, {DateTime.friday, DateTime.saturday});

    await Db.i.updateEmployee(
        saved.copyWith(opener: false, workingDays: const {}));
    final updated = (await Db.i.employees()).single;
    expect(updated.opener, isFalse);
    expect(updated.workingDays, isEmpty);
  });

  test('guarda y relee el consumo de una noche', () async {
    final d = await Db.openAt(p.join(dir.path, 'consumo.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    await Db.i.addProduct(
      Product(
        name: 'Cerveza',
        category: 'Cervezas',
        groupName: 'Cerveza',
        box: const CrateType('Caja', 24, 1, 1, 1, 5),
      ),
      groupImage: null,
    );
    final product = (await Db.i.products()).single;

    await Db.i.saveNight('2026-10-10', {product.id!: 30});
    expect(await Db.i.nightConsumption('2026-10-10'), {product.id!: 30});
    expect(await Db.i.nightConsumption('2026-10-11'), isEmpty);

    // Volver a guardar esa noche sustituye el consumo anterior.
    await Db.i.saveNight('2026-10-10', {product.id!: 12});
    expect(await Db.i.nightConsumption('2026-10-10'), {product.id!: 12});
  });

  test('repara los grupos históricos de variantes (v8 -> v9)', () async {
    final path = p.join(dir.path, 'orphans.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (d, _) async {
          await _createLegacyV7(d);
          // Nombres históricos que en su día quedaron sin grupo.
          for (final name in [
            'Aquarius Naranja',
            'Ginger Ale',
            'Tónica Bliss'
          ]) {
            await d.insert('products', {
              'name': name,
              'category': 'Refrescos y zumos',
              'size': 1.0,
              'height': 0.5,
              'format': 1,
              'crate_name': 'Nestea',
              'trip_capacity': 6,
              'units_per_box': 24,
            });
          }
          await d.insert('products', {
            'name': 'Aquarius Limón',
            'category': 'Refrescos y zumos',
            'size': 1.0,
            'height': 0.5,
            'format': 1,
            'crate_name': 'Nestea',
            'trip_capacity': 6,
            'units_per_box': 24,
            'group_name': 'Aquarius',
            'subcategory': 'Limón',
          });
        },
      ),
    );
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    Future<Map<String, Object?>> product(String name) async =>
        (await d.rawQuery(
          '''
          SELECT g.name AS grp, s.name AS sub
          FROM product p
          JOIN product_group g ON g.id = p.group_id
          LEFT JOIN subcategory s ON s.id = p.subcategory_id
          WHERE p.name = ?''',
          [name],
        ))
            .single;

    final naranja = await product('Aquarius Naranja');
    expect(naranja['grp'], 'Aquarius');
    expect(naranja['sub'], 'Naranja');

    final limon = await product('Aquarius Limón');
    expect(limon['grp'], 'Aquarius');
    expect(limon['sub'], 'Limón');

    final ginger = await product('Ginger Ale');
    expect(ginger['grp'], 'Bliss');
    expect(ginger['sub'], 'Ginger Ale');

    final tonica = await product('Tónica Bliss');
    expect(tonica['grp'], 'Bliss');
    expect(tonica['sub'], 'Tónica');

    // Los grupos huérfanos (nombre propio) se han eliminado.
    final orphans = await d.query('product_group',
        columns: ['name'],
        where: 'name IN (?, ?, ?)',
        whereArgs: ['Aquarius Naranja', 'Ginger Ale', 'Tónica Bliss']);
    expect(orphans, isEmpty);
  });

  test('agrupa las cervezas por marca (Cruzcampo, Heineken, Otros) en v10',
      () async {
    final path = p.join(dir.path, 'beers.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (d, _) async {
          await _createLegacyV7(d);
          for (final name in [
            '1904',
            'Cruzcampo Gran Reserva',
            'Cruzcampo Radler',
            'Heineken',
            'Heineken 0,0',
            'Sol',
            'Guinness',
          ]) {
            await d.insert('products', {
              'name': name,
              'category': 'Cervezas y similares',
              'size': 1.0,
              'height': 1.0,
              'format': 2,
              'crate_name': 'Cerveza',
              'trip_capacity': 5,
              'units_per_box': 24,
            });
          }
        },
      ),
    );
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    Future<Map<String, Object?>> beer(String name) async =>
        (await d.rawQuery('''
          SELECT g.name AS grp, s.name AS sub
          FROM product p
          JOIN product_group g ON g.id = p.group_id
          LEFT JOIN subcategory s ON s.id = p.subcategory_id
          WHERE p.name = ?''', [name])).single;

    expect((await beer('Cruzcampo'))['grp'], 'Cruzcampo');
    expect((await beer('Cruzcampo'))['sub'], 'Pilsen');
    expect((await beer('1904'))['grp'], 'Cruzcampo');
    expect((await beer('1904'))['sub'], '1904');
    expect((await beer('Cruzcampo Gran Reserva'))['sub'], 'Gran Reserva');
    expect((await beer('Cruzcampo Radler'))['sub'], 'Radler');
    expect((await beer('Heineken'))['grp'], 'Heineken');
    expect((await beer('Heineken'))['sub'], 'Normal');
    expect((await beer('Heineken 0,0'))['sub'], '0,0');
    expect((await beer('Sol'))['grp'], 'Otros');
    expect((await beer('Sol'))['sub'], 'Sol');
    expect((await beer('Guinness'))['grp'], 'Otros');
    expect((await beer('Guinness'))['sub'], 'Guinness');

    // Solo quedan los tres grupos de marca en cervezas.
    final groups = await d.rawQuery('''
      SELECT DISTINCT g.name AS name
      FROM product_group g
      JOIN category c ON c.id = g.category_id
      WHERE c.name = 'Cervezas y similares'
      ORDER BY g.name''');
    expect(groups.map((r) => r['name']).toList(),
        ['Cruzcampo', 'Heineken', 'Otros']);

    // v11: se asocia la imagen del grupo Cruzcampo (Heineken/Otros no tienen).
    final images = {
      for (final r in await d.rawQuery('''
        SELECT g.name AS name, g.image AS image
        FROM product_group g
        JOIN category c ON c.id = g.category_id
        WHERE c.name = 'Cervezas y similares' '''))
        r['name'] as String: r['image'],
    };
    expect(images['Cruzcampo'], 'lib/img/cruzcampo.jfif');
    expect(images['Heineken'], isNull);
  });
}
