import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_bar/auth.dart';
import 'package:stock_bar/db.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/seed.dart';
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
        'users',
        'shift',
      ]),
    );
    expect((await d.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);

    final userCols = (await d.rawQuery('PRAGMA table_info(users)'))
        .map((r) => r['name'])
        .toSet();
    expect(
      userCols,
      containsAll([
        'name',
        'surname',
        'email',
        'password_hash',
        'password_salt',
        'role',
        'role_id',
        'opener',
        'working_days',
      ]),
    );
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
    expect(tables, containsAll(['role', 'users', 'shift']));
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
    await expectLater(
      Db.i.addRole(
        const JobRole(name: ' KARAOKE ', floor: Floor.terraza),
      ),
      throwsA(isA<StateError>()),
    );

    await Db.i.addUser(
      AppUser(
        name: 'Ana',
        email: 'ana@favorita.local',
        jobRole: roles.single,
        opener: true,
      ),
      password: 'secreto1',
    );
    final users = await Db.i.users();
    expect(users.single.name, 'Ana');
    expect(users.single.email, 'ana@favorita.local');
    expect(users.single.jobRole?.floor, Floor.karaoke);
    expect(users.single.role, UserRole.employee);

    final generated = ShiftGenerator.generateMonth(
      month: DateTime(2026, 10),
      users: users,
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

    await Db.i.setUserActive(users.single.id!, false);
    expect(await Db.i.users(), isEmpty);
    expect((await Db.i.users(includeInactive: true)).length, 1);

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
    await Db.i.addUser(
      AppUser(
        name: 'Ana',
        email: 'ana@favorita.local',
        jobRole: role,
        opener: true,
        workingDays: const {DateTime.friday, DateTime.saturday},
      ),
      password: 'secreto1',
    );

    final saved = (await Db.i.users()).single;
    expect(saved.opener, isTrue);
    expect(saved.workingDays, {DateTime.friday, DateTime.saturday});
    expect(saved.role, UserRole.employee);

    await Db.i.updateUser(
      saved.copyWith(role: UserRole.admin),
    );
    final promoted = (await Db.i.users()).single;
    expect(promoted.role, UserRole.admin);

    await Db.i.updateUser(
      promoted.copyWith(opener: false, workingDays: const {}),
    );
    final updated = (await Db.i.users()).single;
    expect(updated.opener, isFalse);
    expect(updated.workingDays, isEmpty);
  });

  test('registro, login y cambio de contraseña', () async {
    final d = await Db.openAt(p.join(dir.path, 'auth.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    final user = await Db.i.registerUser(
      name: 'Nuevo',
      surname: 'Usuario',
      email: 'Nuevo@Ejemplo.com',
      password: 'clave123',
    );
    expect(user.email, 'nuevo@ejemplo.com');
    expect(user.jobRole, isNull);
    expect(user.role, UserRole.employee);
    expect((await Db.i.currentUser())?.id, user.id);

    await Db.i.logout();
    expect(await Db.i.currentUser(), isNull);
    expect(await Db.i.authenticate('nuevo@ejemplo.com', 'mala'), isNull);

    final logged = await Db.i.authenticate('NUEVO@ejemplo.com', 'clave123');
    expect(logged?.id, user.id);
    expect((await Db.i.currentUser())?.email, 'nuevo@ejemplo.com');

    await Db.i.changePassword(user.id!, 'clave123', 'nueva123');
    await Db.i.logout();
    expect(await Db.i.authenticate('nuevo@ejemplo.com', 'clave123'), isNull);
    expect(
      (await Db.i.authenticate('nuevo@ejemplo.com', 'nueva123'))?.id,
      user.id,
    );

    await expectLater(
      Db.i.registerUser(
        name: 'Otra',
        surname: '',
        email: 'nuevo@ejemplo.com',
        password: 'clave123',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('migra employees a users conservando turnos y clave temporal', () async {
    final path = p.join(dir.path, 'v15.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 15,
        onCreate: (d, _) async {
          await d.execute('''CREATE TABLE role(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            floor TEXT NOT NULL DEFAULT 'planta_baja',
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)''');
          await d.execute('''CREATE TABLE employee(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            role_id INTEGER NOT NULL REFERENCES role(id),
            active INTEGER NOT NULL DEFAULT 1,
            opener INTEGER NOT NULL DEFAULT 0,
            working_days TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)''');
          await d.execute('''CREATE TABLE shift(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            employee_id INTEGER NOT NULL REFERENCES employee(id),
            role_id INTEGER NOT NULL REFERENCES role(id),
            role_name TEXT NOT NULL,
            floor TEXT NOT NULL,
            start_min INTEGER NOT NULL,
            end_min INTEGER NOT NULL,
            break_min INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'borrador',
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE(employee_id, date))''');
        },
      ),
    );
    final roleId = await legacy.insert('role', {
      'name': 'Sala',
      'floor': 'planta_baja',
      'note': null,
      'created_at': 1,
      'updated_at': 1,
    });
    final employeeId = await legacy.insert('employee', {
      'name': 'María Moreno',
      'role_id': roleId,
      'active': 1,
      'opener': 1,
      'working_days': '5,6',
      'created_at': 1,
      'updated_at': 1,
    });
    await legacy.insert('shift', {
      'date': '2026-10-02',
      'employee_id': employeeId,
      'role_id': roleId,
      'role_name': 'Sala',
      'floor': 'planta_baja',
      'start_min': 960,
      'end_min': 1260,
      'break_min': 0,
      'status': 'borrador',
      'note': null,
      'created_at': 1,
      'updated_at': 1,
    });
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    final user = (await d.query('users')).single;
    expect(user['id'], employeeId);
    expect(user['name'], 'María');
    expect(user['surname'], 'Moreno');
    expect(user['email'], 'maria.moreno@favorita.local');
    expect(user['opener'], 1);
    expect(user['working_days'], '5,6');
    expect(
      PasswordHasher.verify(
        kSeedPassword,
        user['password_salt'] as String,
        user['password_hash'] as String,
      ),
      isTrue,
    );

    final shift = (await d.query('shift')).single;
    expect(shift['user_id'], employeeId);
    expect(shift['user_name'], 'María Moreno');
    final tables = (await d
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(tables, isNot(contains('employee')));
  });

  test('la semilla reutiliza un puesto existente sin duplicarlo', () async {
    final d = await Db.openAt(p.join(dir.path, 'seed_roles.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    await Db.i.addRole(
      const JobRole(name: ' Camarero ', floor: Floor.terraza),
    );
    await Db.i.seedStaff(initialRoles, initialUsers);

    final roles = await d.query('role', orderBy: 'id');
    expect(roles.length, initialRoles.length);
    final keys = roles.map((r) => r['name_key']).toList();
    expect(keys.toSet().length, keys.length);

    final carmen = (await Db.i.users())
        .firstWhere((u) => u.email == 'carmen@favorita.local');
    expect(carmen.jobRole?.name, 'Camarero');
    expect(carmen.role, UserRole.employee);
  });

  test('v17 fusiona puestos duplicados y reasigna usuarios y turnos', () async {
    final path = p.join(dir.path, 'roles_duplicados.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 16,
        onCreate: (d, _) async {
          await d.execute('''CREATE TABLE role(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            floor TEXT NOT NULL DEFAULT 'planta_baja',
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)''');
          await d.execute('''CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            role_id INTEGER,
            updated_at INTEGER NOT NULL)''');
          await d.execute('''CREATE TABLE shift(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            role_id INTEGER NOT NULL,
            role_name TEXT NOT NULL,
            floor TEXT NOT NULL,
            updated_at INTEGER NOT NULL)''');
        },
      ),
    );
    final canonicalId = await legacy.insert('role', {
      'name': 'Camarero',
      'floor': 'planta_baja',
      'note': null,
      'created_at': 1,
      'updated_at': 1,
    });
    final duplicateId = await legacy.insert('role', {
      'name': ' camarero ',
      'floor': 'terraza',
      'note': null,
      'created_at': 1,
      'updated_at': 1,
    });
    await legacy.insert('role', {
      'name': 'Karaoke',
      'floor': 'karaoke',
      'note': null,
      'created_at': 1,
      'updated_at': 1,
    });
    final userId = await legacy.insert('users', {
      'name': 'Ana',
      'role_id': duplicateId,
      'updated_at': 1,
    });
    await legacy.insert('shift', {
      'user_id': userId,
      'role_id': duplicateId,
      'role_name': ' camarero ',
      'floor': 'terraza',
      'updated_at': 1,
    });
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    final roles = await d.query('role', orderBy: 'id');
    expect(roles.length, 2);
    expect(roles.first['id'], canonicalId);
    expect(roles.first['name'], 'Camarero');
    expect(roles.first['name_key'], 'camarero');
    expect(roles.last['name_key'], 'karaoke');

    final user = (await d.query('users')).single;
    expect(user['role_id'], canonicalId);
    final shift = (await d.query('shift')).single;
    expect(shift['role_id'], canonicalId);
    expect(shift['role_name'], 'Camarero');
    expect(shift['floor'], 'planta_baja');

    final indexes = (await d.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_role_name_key'],
    ));
    expect(indexes, isNotEmpty);
  });

  test('v18 añade el rol de acceso y solo Alejandro es admin', () async {
    final path = p.join(dir.path, 'roles_acceso.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 17,
        onCreate: (d, _) async {
          await d.execute('''CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            surname TEXT NOT NULL DEFAULT '',
            email TEXT NOT NULL,
            updated_at INTEGER NOT NULL)''');
        },
      ),
    );
    await legacy.insert('users', {
      'name': 'Alejandro',
      'surname': '',
      'email': 'alejandro@favorita.local',
      'updated_at': 1,
    });
    await legacy.insert('users', {
      'name': 'Carmen',
      'surname': '',
      'email': 'carmen@favorita.local',
      'updated_at': 1,
    });
    await legacy.insert('users', {
      'name': 'Alejandro',
      'surname': 'Pérez',
      'email': 'alejandro.perez@favorita.local',
      'updated_at': 1,
    });
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    final rows = await d.query('users', orderBy: 'id');
    expect(rows[0]['role'], UserRole.admin.db);
    expect(rows[1]['role'], UserRole.employee.db);
    expect(rows[2]['role'], UserRole.employee.db);
    expect(rows.where((r) => r['role'] == UserRole.admin.db).length, 1);
  });

  test('siembra puestos y usuarios iniciales con clave temporal', () async {
    final d = await Db.openAt(p.join(dir.path, 'seed.db'));
    Db.i.useDatabase(d);
    addTearDown(() async {
      Db.i.useDatabase(null);
      await d.close();
    });

    await Db.i.seedStaff(initialRoles, initialUsers);

    final users = await Db.i.users();
    expect(users.length, initialUsers.length);
    final carmen = users.firstWhere((u) => u.email == 'carmen@favorita.local');
    expect(carmen.fullName, 'Carmen');
    expect(carmen.jobRole?.name, 'camarero');
    expect(carmen.role, UserRole.employee);
    final alejandro =
        users.firstWhere((u) => u.email == 'alejandro@favorita.local');
    expect(alejandro.role, UserRole.admin);
    expect(users.where((u) => u.role == UserRole.admin).length, 1);
    expect(
      (await Db.i.authenticate('carmen@favorita.local', kSeedPassword))?.id,
      carmen.id,
    );
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

  test('rellena las imágenes pendientes de grupos ya migrados (v15)', () async {
    final path = p.join(dir.path, 'group_images.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 14,
        onCreate: (d, _) async {
          await d.execute('''CREATE TABLE product_group(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            image TEXT,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0)''');
          // Base ya en v14: Aquarius migrado, el resto aún sin imagen.
          await d.insert('product_group', {
            'category_id': 1,
            'name': 'Aquarius',
            'image': 'lib/img/aquarius.png',
          });
          for (final name in ['Coca-Cola', 'Nestea', 'Bliss']) {
            await d.insert('product_group', {'category_id': 1, 'name': name});
          }
          await d.insert('product_group', {
            'category_id': 1,
            'name': 'Cruzcampo',
            'image': 'lib/img/otra.png',
          });
        },
      ),
    );
    await legacy.close();

    final d = await Db.openAt(path);
    addTearDown(d.close);

    final images = {
      for (final r in await d.query('product_group'))
        r['name'] as String: r['image'],
    };
    expect(images['Aquarius'], 'lib/img/aquarius.png');
    expect(images['Coca-Cola'], 'lib/img/coca-cola.png');
    expect(images['Nestea'], 'lib/img/fuze-tea.png');
    expect(images['Bliss'], 'lib/img/royal-bliss.jpg');
    // La migración solo rellena grupos sin imagen.
    expect(images['Cruzcampo'], 'lib/img/otra.png');
  });
}
