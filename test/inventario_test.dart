import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stock_bar/db.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/inventario.dart';

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
      for (var i = 0; i < 50 && find.text('2 cajas').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(find.text('Cerveza'), findsOneWidget);
      expect(find.text('2 cajas'), findsOneWidget);
      expect(find.text('+ 5 uds'), findsOneWidget);
    } finally {
      await tester.runAsync(() async {
        Db.i.useDatabase(null);
        await database.close();
      });
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });
}
