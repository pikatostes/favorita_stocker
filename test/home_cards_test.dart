import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/screens/home/home_cards.dart';
import 'package:stock_bar/screens/home/home_data.dart';
import 'package:stock_bar/shifts.dart';
import 'package:stock_bar/theme.dart';
import 'package:stock_bar/widgets/quantity_stepper.dart';

AppUser _user({UserRole role = UserRole.admin, String name = 'Alejandro'}) =>
    AppUser(
      id: 1,
      name: name,
      surname: 'Ribera',
      role: role,
      jobRole: const JobRole(name: 'Camarero'),
      opener: true,
    );

HomeData _data({bool withNightList = false}) => HomeData(
      now: DateTime(2026, 11, 9, 20, 30),
      serviceDay: DateTime(2026, 11, 9),
      focusDay: DateTime(2026, 11, 9),
      nextOpen: DateTime(2026, 11, 10),
      openNow: true,
      opensLaterToday: false,
      special: const {},
      users: [_user(), _user(role: UserRole.employee, name: 'Lucía')],
      monthShifts: [
        const Shift(
          date: '2026-11-09',
          userId: 1,
          userName: 'Alejandro Ribera',
          roleId: 1,
          roleName: 'Camarero',
          floor: Floor.plantaBaja,
          startMin: 16 * 60,
          endMin: 24 * 60,
          breakMin: 25,
          status: ShiftStatus.published,
        ),
      ],
      focusShifts: const [
        Shift(
          date: '2026-11-09',
          userId: 1,
          userName: 'Alejandro Ribera',
          roleId: 1,
          roleName: 'Camarero',
          floor: Floor.plantaBaja,
          startMin: 16 * 60,
          endMin: 24 * 60,
          breakMin: 25,
          status: ShiftStatus.published,
        ),
      ],
      myUpcoming: [
        const Shift(
          date: '2026-11-09',
          userId: 1,
          userName: 'Alejandro Ribera',
          roleId: 1,
          roleName: 'Camarero',
          floor: Floor.plantaBaja,
          startMin: 16 * 60,
          endMin: 24 * 60,
          breakMin: 25,
          status: ShiftStatus.published,
        ),
      ],
      mySchedulePending: false,
      forecast: ForecastResult([
        Forecast(
          Product(id: 7, name: 'Cruzcampo', groupName: 'Cruzcampo'),
          96,
        ),
      ], 4, 2),
      nightList: withNightList
          ? const NightListSummary(
              date: '2026-11-09',
              floor: Floor.terraza,
              qty: {7: 12},
              fullBoxes: {7: 4},
              totalUnits: 108,
              products: 1,
            )
          : null,
    );

Widget _app(Widget child) => MaterialApp(
      theme: AppPalettes.favorita.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

Future<void> _setViewport(
    WidgetTester tester, double width, double height) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('HomeHeader no desborda', () {
    for (final size in const [Size(375, 812), Size(1440, 900)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _setViewport(tester, size.width, size.height);
        await tester.pumpWidget(
          _app(HomeHeader(data: _data(), user: _user())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hola, Alejandro'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('tarjetas de Inicio no desbordan', () {
    for (final size in const [Size(375, 812), Size(1440, 900)]) {
      testWidgets('admin ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _setViewport(tester, size.width, size.height);
        final data = _data(withNightList: true);
        await tester.pumpWidget(_app(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminTonightCard(data: data),
            const SizedBox(height: 16),
            AdminPlanningCard(
              data: data,
              working: false,
              onGenerate: () {},
              onPublish: () {},
            ),
            const SizedBox(height: 16),
            MaintenanceListCard(data: data, onOpen: (_) {}),
          ],
        )));
        await tester.pumpAndSettle();

        expect(find.text('Esta noche · Lun 9 nov'), findsOneWidget);
        expect(find.text('Ver plan de montaje'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empleado ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _setViewport(tester, size.width, size.height);
        final data = _data();
        final employee = _user(role: UserRole.employee, name: 'Lucía');
        await tester.pumpWidget(_app(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyDayCard(data: data, user: employee),
            const SizedBox(height: 16),
            EmployeeTonightCard(data: data),
          ],
        )));
        await tester.pumpAndSettle();

        expect(find.text('Mi turno'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('QuantityStepper', () {
    testWidgets('mantiene áreas táctiles de 44 px y avisa del valor',
        (tester) async {
      await _setViewport(tester, 375, 812);
      final semantics = tester.ensureSemantics();
      var value = 1;
      await tester.pumpWidget(MaterialApp(
        theme: AppPalettes.favorita.dark,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => QuantityStepper(
                label: 'Cajas',
                value: value,
                onDecrement:
                    value > 0 ? () => setState(() => value -= 1) : null,
                onIncrement: () => setState(() => value += 1),
              ),
            ),
          ),
        ),
      ));

      expect(find.bySemanticsLabel(RegExp('Cajas: 1')), findsOneWidget);
      final minus = find.byTooltip('Quitar Cajas');
      final plus = find.byTooltip('Añadir Cajas');
      expect(tester.getSize(minus).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(plus).width, greaterThanOrEqualTo(44));

      await tester.tap(plus);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await tester.tap(minus);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
