import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/turnos/users/user_form_dialog.dart';
import 'package:stock_bar/shifts.dart';

/// Usuario de ejemplo con planta y puesto ya asignados.
AppUser _user({
  Floor floor = Floor.plantaBaja,
  JobPosition position = JobPosition.camarero,
}) =>
    AppUser(
      id: 7,
      name: 'Ana',
      surname: 'Pérez',
      email: 'ana@favorita.local',
      floor: floor,
      jobPosition: position,
    );

/// Abre [UserFormDialog] en un diálogo real y devuelve la lista donde se
/// guarda el resultado al cerrarlo con «Guardar».
Future<List<UserFormResult?>> _open(WidgetTester tester, AppUser user) async {
  final results = <UserFormResult?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(
                  await showDialog<UserFormResult>(
                    context: context,
                    builder: (_) => UserFormDialog(user: user),
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
///
/// Los `DropdownButton` mantienen todos sus items en el árbol (IndexedStack),
/// así que la opción visible del menú es la última coincidencia.
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
  testWidgets('pasar a manteni fuerza la planta baja', (tester) async {
    final results = await _open(
      tester,
      _user(floor: Floor.terraza, position: JobPosition.camarero),
    );

    await _pick<JobPosition>(tester, 'Manteni');
    await _save(tester);

    final saved = results.single!.user;
    expect(saved.id, 7);
    expect(saved.jobPosition, JobPosition.manteni);
    expect(saved.floor, Floor.plantaBaja);
    expect(saved.effectiveFloor, Floor.plantaBaja);
  });

  testWidgets('de manteni a camarero se puede elegir otra planta',
      (tester) async {
    final results = await _open(
      tester,
      _user(floor: Floor.plantaBaja, position: JobPosition.manteni),
    );

    await _pick<JobPosition>(tester, 'Camarero');
    await _pick<Floor>(tester, 'Terraza');
    await _save(tester);

    final saved = results.single!.user;
    expect(saved.jobPosition, JobPosition.camarero);
    expect(saved.floor, Floor.terraza);
    expect(saved.effectiveFloor, Floor.terraza);
  });

  testWidgets('se puede dejar al usuario sin puesto', (tester) async {
    final results = await _open(tester, _user());

    await tester.ensureVisible(find.text('Dejar sin puesto'));
    await tester.tap(find.text('Dejar sin puesto'));
    await tester.pumpAndSettle();
    await _save(tester);

    final saved = results.single!.user;
    expect(saved.jobPosition, isNull);
    expect(saved.floor, Floor.plantaBaja);
  });

  testWidgets('cambiar solo la planta mantiene el puesto', (tester) async {
    final results = await _open(tester, _user(floor: Floor.plantaBaja));

    await _pick<Floor>(tester, 'Karaoke');
    await _save(tester);

    final saved = results.single!.user;
    expect(saved.floor, Floor.karaoke);
    expect(saved.jobPosition, JobPosition.camarero);
    expect(saved.effectiveFloor, Floor.karaoke);
  });

  testWidgets('con manteni la planta no se puede cambiar', (tester) async {
    await _open(tester, _user(position: JobPosition.manteni));

    final floorField = tester.widget<DropdownButtonFormField<Floor>>(
      find.byType(DropdownButtonFormField<Floor>),
    );
    expect(floorField.onChanged, isNull);
  });

  testWidgets('guardar sin tocar el puesto lo conserva', (tester) async {
    final results = await _open(
      tester,
      _user(floor: Floor.karaoke, position: JobPosition.camarero),
    );

    await _save(tester);

    final saved = results.single!.user;
    expect(saved.jobPosition, JobPosition.camarero);
    expect(saved.floor, Floor.karaoke);
  });
}
