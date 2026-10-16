import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/widgets/category_tabs.dart';

Widget _app(List<Product> products) => MaterialApp(
      home: Scaffold(
        body: CategoryTabs(
          products: products,
          builder: (_, list) => ListView(
            children: [for (final p in list) Text(p.name)],
          ),
        ),
      ),
    );

Product _p(int id, String name, String category) =>
    Product(id: id, name: name, category: category);

void main() {
  testWidgets('añadir una categoría nueva no lanza excepción', (tester) async {
    await tester.pumpWidget(_app([_p(1, 'Cruzcampo', 'Cervezas')]));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app([
      _p(1, 'Cruzcampo', 'Cervezas'),
      _p(2, 'Coca-Cola', 'Refrescos'),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renombrar la categoría de un producto no lanza excepción',
      (tester) async {
    await tester.pumpWidget(_app([_p(1, 'Cruzcampo', 'Cervezas')]));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app([_p(1, 'Cruzcampo', 'Birras')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('alternar CategoryTabs con otra pantalla no lanza excepción',
      (tester) async {
    await tester.pumpWidget(_app([
      _p(1, 'Cruzcampo', 'Cervezas'),
      _p(2, 'Coca-Cola', 'Refrescos'),
    ]));
    await tester.pumpAndSettle();

    // Simula el FutureBuilder que muestra un loader mientras recarga.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    ));
    await tester.pumpWidget(_app([
      _p(1, 'Cruzcampo', 'Cervezas'),
      _p(2, 'Coca-Cola', 'Refrescos'),
      _p(3, 'Agua', 'Refrescos'),
    ]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
