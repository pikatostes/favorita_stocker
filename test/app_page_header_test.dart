import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/widgets/app_ui.dart';

void main() {
  testWidgets('inlineActions deja las acciones dentro de la cabecera', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPageHeader(
            eyebrow: 'Operación nocturna',
            title: 'Lista de montaje',
            compact: true,
            inlineActions: true,
            leading: SizedBox(width: 24, height: 24),
            actions: [
              Wrap(
                key: Key('acciones'),
                spacing: 4,
                children: [
                  SizedBox(width: 57, height: 44),
                  SizedBox(width: 52, height: 44),
                  SizedBox(width: 44, height: 44),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final title = tester.getRect(find.text('Lista de montaje'));
    final actions = tester.getRect(find.byKey(const Key('acciones')));
    // Título y acciones comparten fila: se solapan en vertical y no en
    // horizontal (las acciones van a la derecha).
    expect(actions.top, lessThan(title.bottom));
    expect(title.top, lessThan(actions.bottom));
    expect(title.right, lessThanOrEqualTo(actions.left));
  });
}
