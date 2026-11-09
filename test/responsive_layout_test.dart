import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/theme.dart';
import 'package:stock_bar/widgets/app_navigation.dart';

const _destinations = [
  AppDestination(
    id: 'start',
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    group: AppNavGroup.operation,
  ),
  AppDestination(
    id: 'list',
    label: 'Lista',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
    group: AppNavGroup.operation,
  ),
  AppDestination(
    id: 'shifts',
    label: 'Turnos',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    group: AppNavGroup.operation,
  ),
  AppDestination(
    id: 'admin',
    label: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    group: AppNavGroup.management,
  ),
  AppDestination(
    id: 'account',
    label: 'Cuenta',
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle,
    group: AppNavGroup.account,
  ),
];

Widget _app({required double width}) => MaterialApp(
      theme: AppPalettes.favorita.dark,
      home: AppNavigationShell(
        destinations: _destinations,
        selectedIndex: 0,
        onSelected: (_) {},
        child: const Scaffold(
          body: Center(child: Text('Contenido')),
        ),
      ),
    );

Future<void> _setViewport(
  WidgetTester tester,
  double width,
  double height,
) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('navegación adaptativa en tamaños reales', () {
    for (final size in const [
      Size(375, 812),
      Size(390, 844),
    ]) {
      testWidgets('móvil ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _setViewport(tester, size.width, size.height);
        await tester.pumpWidget(_app(width: size.width));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Inicio'), findsOneWidget);
        expect(find.text('Cuenta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tablet 768×1024 usa rail lateral', (tester) async {
      await _setViewport(tester, 768, 1024);
      await tester.pumpWidget(_app(width: 768));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(1024, 768),
      Size(1440, 900),
    ]) {
      testWidgets('escritorio ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await _setViewport(tester, size.width, size.height);
        await tester.pumpWidget(_app(width: size.width));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('OPERACIÓN'), findsOneWidget);
        expect(find.text('ADMINISTRACIÓN'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el sidebar de escritorio se puede contraer', (tester) async {
      await _setViewport(tester, 1440, 900);
      await tester.pumpWidget(_app(width: 1440));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Contraer menú'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Expandir menú'), findsOneWidget);
      expect(find.text('OPERACIÓN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
