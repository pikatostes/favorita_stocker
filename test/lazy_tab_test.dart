import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/widgets/lazy_tab.dart';

void main() {
  testWidgets('LazyTab solo construye la pestaña cuando está activa', (
    tester,
  ) async {
    var builtFirst = 0;
    var builtSecond = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: TabBarView(
              children: [
                LazyTab(
                  index: 0,
                  builder: (_) {
                    builtFirst++;
                    return const Text('primera');
                  },
                ),
                LazyTab(
                  index: 1,
                  builder: (_) {
                    builtSecond++;
                    return const Text('segunda');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('primera'), findsOneWidget);
    expect(find.text('segunda'), findsNothing);
    expect(builtSecond, 0);

    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBarView)));
    controller.animateTo(1);
    await tester.pumpAndSettle();

    expect(find.text('segunda'), findsOneWidget);
    expect(builtSecond, greaterThan(0));
    expect(builtFirst, greaterThan(0));
  });

  testWidgets('LazyTab conserva el estado de una pestaña ya abierta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: TabBarView(
              children: [
                LazyTab(index: 0, builder: (_) => const _Counter()),
                LazyTab(index: 1, builder: (_) => const Text('segunda')),
                LazyTab(index: 2, builder: (_) => const Text('tercera')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('incrementar'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBarView)));
    // Salta a la última pestaña para que la primera quede fuera de pantalla.
    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(find.text('tercera'), findsOneWidget);

    controller.animateTo(0);
    await tester.pumpAndSettle();

    // Sin el keep-alive, la pestaña se habría reconstruido y el contador
    // volvería a 0.
    expect(find.text('1'), findsOneWidget);
  });
}

/// Contador con estado propio para comprobar que la pestaña no se recrea.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _value = 0;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$_value'),
          TextButton(
            onPressed: () => setState(() => _value++),
            child: const Text('incrementar'),
          ),
        ],
      );
}
