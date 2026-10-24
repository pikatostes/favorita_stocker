import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/widgets/month_calendar.dart';

Widget _app({
  required ValueChanged<DateTime> onSelect,
  required ValueChanged<DateTime> onMonthChanged,
  CalendarDayStyle Function(DateTime)? styleFor,
  Widget? Function(DateTime)? footerFor,
  DateTime? selected,
  double cellHeight = 44,
}) =>
    MaterialApp(
      home: Scaffold(
        body: MonthCalendar(
          month: DateTime(2026, 10),
          selected: selected ?? DateTime(2026, 10, 15),
          onSelect: onSelect,
          onMonthChanged: onMonthChanged,
          styleFor: styleFor,
          footerFor: footerFor,
          cellHeight: cellHeight,
        ),
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets('muestra el mes completo con la cabecera en español',
      (tester) async {
    await tester.pumpWidget(_app(
      onSelect: (_) {},
      onMonthChanged: (_) {},
    ));

    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    // Octubre de 2026 empieza en jueves: tres huecos antes del día 1.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tocar un día notifica la fecha seleccionada', (tester) async {
    final selected = <DateTime>[];
    await tester.pumpWidget(_app(
      onSelect: selected.add,
      onMonthChanged: (_) {},
    ));

    await tester.tap(find.text('20'));
    await tester.pump();

    expect(selected, [DateTime(2026, 10, 20)]);
  });

  testWidgets('los botones de mes llaman a onMonthChanged', (tester) async {
    final months = <DateTime>[];
    await tester.pumpWidget(_app(
      onSelect: (_) {},
      onMonthChanged: months.add,
    ));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(months, [DateTime(2026, 9), DateTime(2026, 11)]);
  });

  testWidgets('aplica el estilo del día y muestra el pie', (tester) async {
    await tester.pumpWidget(_app(
      onSelect: (_) {},
      onMonthChanged: (_) {},
      styleFor: (day) => day.day == 10
          ? const CalendarDayStyle(fill: Color(0xFF123456))
          : const CalendarDayStyle(),
      footerFor: (day) => day.day == 10 ? const Text('3 turnos') : null,
      cellHeight: 60,
    ));

    final circle = tester.widget<Container>(
      find
          .ancestor(of: find.text('10'), matching: find.byType(Container))
          .first,
    );
    expect(
      (circle.decoration as BoxDecoration?)?.color,
      const Color(0xFF123456),
    );
    expect(find.text('3 turnos'), findsOneWidget);
  });

  testWidgets('sin pie, el día solo muestra su número', (tester) async {
    await tester.pumpWidget(_app(
      onSelect: (_) {},
      onMonthChanged: (_) {},
    ));

    expect(find.text('3 turnos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
