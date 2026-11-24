import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/turnos/schedule/plan_config_dialog.dart';
import 'package:stock_bar/shifts.dart';

AppUser _user(int id, String name) => AppUser(
      id: id,
      name: name,
      floor: Floor.plantaBaja,
      jobPosition: JobPosition.camarero,
      opener: true,
    );

/// Abre la card de configuración y devuelve la lista donde se guarda la
/// configuración al confirmar.
Future<List<ShiftPlanConfig?>> _open(
  WidgetTester tester, {
  int existingShifts = 0,
}) async {
  final results = <ShiftPlanConfig?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(
                  await showShiftPlanDialog(
                    context,
                    month: DateTime(2026, 10),
                    users: [_user(1, 'Ana'), _user(2, 'Luis')],
                    specialDays: const <String, SpecialDay>{},
                    existingShifts: existingShifts,
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('Generar horario'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  setUp(() {
    shiftPlanConfigNotifier.value = const ShiftPlanConfig();
  });

  testWidgets('muestra los valores por defecto y la vista previa',
      (tester) async {
    await _open(tester);

    expect(find.text('Horario de Octubre 2026'), findsOneWidget);
    expect(
      find.text('Se generarán 20 turnos para 2 personas.'),
      findsOneWidget,
    );
    for (final weekday in [DateTime.friday, DateTime.saturday]) {
      expect(
        tester
            .widget<FilterChip>(find.byKey(ValueKey('weekday-$weekday')))
            .selected,
        isTrue,
      );
    }
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('weekday-1')))
          .selected,
      isFalse,
    );
  });

  testWidgets('devuelve la configuración al confirmar', (tester) async {
    final results = await _open(tester);
    await _confirm(tester);

    expect(results.single, const ShiftPlanConfig());
    expect(shiftPlanConfigNotifier.value, const ShiftPlanConfig());
  });

  testWidgets('añade un día y lo recuerda en la sesión', (tester) async {
    final first = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('weekday-4')));
    await tester.pumpAndSettle();
    await _confirm(tester);

    final config = first.single!;
    expect(config.weekdays, contains(DateTime.thursday));
    expect(shiftPlanConfigNotifier.value, config);

    // Al volver a abrirla, el jueves sigue marcado.
    await _open(tester);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('weekday-4')))
          .selected,
      isTrue,
    );
  });

  testWidgets('desactiva los turnos completos', (tester) async {
    final results = await _open(tester);

    await tester.ensureVisible(find.text('Permitir turnos completos'));
    await tester.tap(find.text('Permitir turnos completos'));
    await tester.pumpAndSettle();
    await _confirm(tester);

    expect(results.single!.allowFullShifts, isFalse);
  });

  testWidgets('no deja generar sin días', (tester) async {
    await _open(tester);

    for (final weekday in [DateTime.friday, DateTime.saturday]) {
      await tester.tap(find.byKey(ValueKey('weekday-$weekday')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Elige al menos un día de la semana.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Generar horario'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('avisa de los turnos que se van a borrar', (tester) async {
    await _open(tester, existingShifts: 12);

    expect(
      find.textContaining('Se borrarán los 12 turnos actuales'),
      findsOneWidget,
    );
  });

  testWidgets('cambia los mínimos de una planta', (tester) async {
    final results = await _open(tester);

    final field = find.descendant(
      of: find.byKey(const ValueKey('min-terraza-open')),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    await _confirm(tester);

    expect(
      results.single!.minimumsFor(Floor.terraza),
      const FloorMinimums(open: 3, peak: 2),
    );
  });
}
