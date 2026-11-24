import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/screens/turnos/schedule/shift_dialog.dart';
import 'package:stock_bar/shifts.dart';

Shift _shift({
  JobPosition position = JobPosition.camarero,
  Floor floor = Floor.plantaBaja,
}) =>
    Shift(
      id: 3,
      date: '2026-10-02',
      userId: 1,
      userName: 'Ana',
      position: position,
      positionName: position.label,
      floor: floor,
      startMin: 16 * 60,
      endMin: 21 * 60,
      breakMin: 0,
      status: ShiftStatus.draft,
    );

/// Abre [ShiftDialog] en un diálogo real y devuelve la lista donde se guarda
/// el turno editado al cerrarlo con «Guardar».
Future<List<Shift?>> _open(WidgetTester tester, Shift shift) async {
  final results = <Shift?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(
                  await showDialog<Shift>(
                    context: context,
                    builder: (_) => ShiftDialog(shift: shift),
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

/// Elige una opción en el desplegable del tipo indicado.
Future<void> _pick<T>(WidgetTester tester, String option) async {
  final dropdown = find.byType(DropdownButtonFormField<T>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets('la planta del turno se puede cambiar', (tester) async {
    final results = await _open(tester, _shift(floor: Floor.plantaBaja));

    await _pick<Floor>(tester, 'Terraza');
    await _save(tester);

    final saved = results.single!;
    expect(saved.floor, Floor.terraza);
    expect(saved.position, JobPosition.camarero);
  });

  testWidgets('pasar el turno a manteni lo lleva a planta baja', (tester) async {
    final results = await _open(tester, _shift(floor: Floor.terraza));

    await _pick<JobPosition>(tester, 'Manteni');
    await _save(tester);

    final saved = results.single!;
    expect(saved.position, JobPosition.manteni);
    expect(saved.positionName, 'Manteni');
    expect(saved.floor, Floor.plantaBaja);
  });

  testWidgets('de manteni a camarero se puede elegir otra planta',
      (tester) async {
    final results = await _open(
      tester,
      _shift(position: JobPosition.manteni, floor: Floor.plantaBaja),
    );

    await _pick<JobPosition>(tester, 'Camarero');
    await _pick<Floor>(tester, 'Karaoke');
    await _save(tester);

    final saved = results.single!;
    expect(saved.position, JobPosition.camarero);
    expect(saved.floor, Floor.karaoke);
  });

  testWidgets('con manteni la planta del turno está bloqueada', (tester) async {
    await _open(
      tester,
      _shift(position: JobPosition.manteni, floor: Floor.plantaBaja),
    );

    final floorField = tester.widget<DropdownButtonFormField<Floor>>(
      find.byType(DropdownButtonFormField<Floor>),
    );
    expect(floorField.onChanged, isNull);
  });
}
