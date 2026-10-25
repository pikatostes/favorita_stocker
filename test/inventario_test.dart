import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_bar/db.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/inventario.dart';

/// Espera a que la consulta real a SQLite haga aparecer [finder].
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('muestra cajas completas y unidades sobrantes', (tester) async {
    final dir = Directory.systemTemp.createTempSync('inventario_test');
    late Database database;
    await tester.runAsync(() async {
      database = await Db.openAt(p.join(dir.path, 'inventario.db'));
      Db.i.useDatabase(database);
      await Db.i.addProduct(
        Product(
          name: 'Cerveza',
          category: 'Cervezas',
          groupName: 'Cerveza',
          box: const CrateType('Caja', 24, 1, 1, 1, 5),
          unitInStock: 53,
        ),
        groupImage: null,
      );
    });

    try {
      await tester.pumpWidget(
        const MaterialApp(home: InventarioScreen(embedded: true)),
      );
      // La consulta a SQLite es asíncrona real: damos tiempo al event loop
      // hasta que el FutureBuilder pinte la lista.
      await _waitFor(tester, find.text('2 cajas'));

      expect(find.text('Cerveza'), findsOneWidget);
      expect(find.text('2 cajas'), findsOneWidget);
      expect(find.text('+ 5 uds'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        Db.i.useDatabase(null);
        await database.close();
      });
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  testWidgets('agrupa variantes y muestra las subcategorías al pulsar',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('inventario_grupo_test');
    late Database database;
    await tester.runAsync(() async {
      database = await Db.openAt(p.join(dir.path, 'inventario_grupo.db'));
      Db.i.useDatabase(database);
      await Db.i.addProduct(
        Product(
          name: 'Coca-Cola',
          category: 'Refrescos',
          groupName: 'Coca-Cola',
          subcategory: 'Original',
          box: const CrateType('Cola', 24, 1, 1, 1, 6),
          unitInStock: 156,
        ),
        groupImage: null,
      );
      await Db.i.addProduct(
        Product(
          name: 'Coca-Cola Zero',
          category: 'Refrescos',
          groupName: 'Coca-Cola',
          subcategory: 'Zero',
          box: const CrateType('Cola', 24, 1, 1, 1, 6),
          unitInStock: 120,
        ),
        groupImage: null,
      );
    });

    try {
      await tester.pumpWidget(
        const MaterialApp(home: InventarioScreen(embedded: true)),
      );
      await _waitFor(tester, find.text('2 subcategorías'));

      // La lista solo muestra el grupo, no cada variante por separado.
      expect(find.text('Coca-Cola'), findsOneWidget);
      expect(find.text('Coca-Cola Zero'), findsNothing);
      expect(find.text('Original'), findsNothing);
      // Stock agregado del grupo: 156 + 120 = 276 = 11 cajas + 12 uds.
      expect(find.text('11 cajas'), findsOneWidget);
      expect(find.text('+ 12 uds'), findsOneWidget);

      await tester.tap(find.text('Coca-Cola'));
      await tester.pumpAndSettle();

      // La tarjeta superpuesta muestra las subcategorías del grupo.
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Zero'), findsOneWidget);
      expect(find.textContaining('Coca-Cola Zero'), findsOneWidget);
      expect(find.text('2 subcategorías'), findsNWidgets(2)); // fila y tarjeta
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        Db.i.useDatabase(null);
        await database.close();
      });
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });
}
