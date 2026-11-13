import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/registro.dart';

void main() {
  Widget harness(double width, {VoidCallback? onSave}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MontajeActionBar(
              contentWidth: width,
              products: 3,
              boxes: 2,
              units: 47,
              onSave: onSave ?? () {},
            ),
          ),
        ),
      );

  testWidgets('en móvil el guardado es una tarjeta compacta', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var saved = 0;
    await tester.pumpWidget(harness(360, onSave: () => saved++));

    expect(tester.takeException(), isNull);
    expect(find.text('Guardar'), findsOneWidget);

    // La acción mantiene el color primario del botón original, 40 px de alto y
    // 128 px de ancho mínimo, sin llegar a ocupar todo el ancho de la pantalla.
    final button = tester.getSize(find.byType(InkWell));
    expect(button.height, 40);
    expect(button.width, greaterThanOrEqualTo(128));
    expect(button.width, lessThan(tester.view.physicalSize.width / 2));

    final inkWell = tester.element(find.byType(InkWell));
    final material = tester.widget<Material>(
      find
          .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
          .first,
    );
    expect(material.color, Theme.of(inkWell).colorScheme.primary);

    await tester.tap(find.byType(InkWell));
    expect(saved, 1);
  });

  testWidgets('en tablet y escritorio se mantiene el botón ancho',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Guardar y montar cajas'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Guardar y montar cajas'),
      findsOneWidget,
    );
    expect(find.text('Guardar'), findsNothing);
  });
}
