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
}
