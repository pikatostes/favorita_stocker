import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/confirmar_lista.dart';

Product _p(int id, String name, String category, int unitsPerBox) => Product(
      id: id,
      name: name,
      category: category,
      box: CrateType('Caja', unitsPerBox, 1, 1, 1, 5),
    );

final _lines = [
  LineaPedido(_p(1, 'Cruzcampo', 'Cervezas', 24), boxes: 2, loose: 3),
  LineaPedido(_p(2, 'Agua', 'Refrescos', 20), boxes: 0, loose: 5),
];

Widget _screen() => MaterialApp(
      home: ConfirmarListaScreen(date: DateTime(2026, 10, 24), lines: _lines),
    );

/// Abre la pantalla desde otra ruta para poder comprobar el valor que devuelve
/// al cerrarse.
Future<void> _open(WidgetTester tester, void Function(bool?) onResult) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => onResult(await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ConfirmarListaScreen(
                  date: DateTime(2026, 10, 24),
                  lines: _lines,
                ),
              ),
            )),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('muestra el resumen del pedido', (tester) async {
    await tester.pumpWidget(_screen());

    expect(find.text('Resumen del pedido'), findsOneWidget);
    expect(find.text('Cruzcampo'), findsOneWidget);
    expect(find.text('2 cajas · 3 sueltos · 24 uds/caja'), findsOneWidget);
    expect(find.text('51 uds'), findsOneWidget);
    expect(find.text('5 sueltos · 20 uds/caja'), findsOneWidget);
    // Totales: 2 productos, 56 botellines, 2 cajas y 8 sueltos.
    expect(find.text('56'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('¿Confirmas que la lista es correcta?'),
      200,
    );
    expect(find.text('¿Confirmas que la lista es correcta?'), findsOneWidget);
  });

  testWidgets('confirmar el pedido devuelve true', (tester) async {
    bool? result;
    await _open(tester, (value) => result = value);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('volver a editar devuelve false', (tester) async {
    bool? result;
    await _open(tester, (value) => result = value);

    await tester.tap(find.text('Volver a editar la lista'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
