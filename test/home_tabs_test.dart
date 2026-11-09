import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/home.dart';
import 'package:stock_bar/shifts.dart';

void main() {
  test('los empleados no ven Calendario, Previsión ni Productos', () {
    final tabs = visibleHomeTabs(UserRole.employee);

    expect(
      tabs,
      [
        HomeTab.start,
        HomeTab.list,
        HomeTab.shifts,
        HomeTab.account,
      ],
    );
    final labels = tabs.map((tab) => tab.label);
    expect(labels, isNot(contains('Calendario')));
    expect(labels, isNot(contains('Previsión')));
    expect(labels, isNot(contains('Productos')));
  });

  test('los administradores ven una única pestaña Admin', () {
    final tabs = visibleHomeTabs(UserRole.admin);

    expect(tabs, HomeTab.values);
    expect(
      tabs.map((tab) => tab.label),
      ['Inicio', 'Lista', 'Turnos', 'Admin', 'Cuenta'],
    );
  });

  group('navegación adaptativa', () {
    test('en web siempre es un menú lateral', () {
      expect(
        homeNavigationMode(isWeb: true, width: 400),
        HomeNavigationMode.compactRail,
      );
      expect(
        homeNavigationMode(isWeb: true, width: 800),
        HomeNavigationMode.rail,
      );
      expect(
        homeNavigationMode(isWeb: true, width: 1400),
        HomeNavigationMode.extendedRail,
      );
    });

    test('en móvil nativo se mantiene la barra inferior', () {
      expect(
        homeNavigationMode(isWeb: false, width: 400),
        HomeNavigationMode.bottomBar,
      );
      expect(
        homeNavigationMode(isWeb: false, width: 800),
        HomeNavigationMode.bottomBar,
      );
    });

    test('en pantallas nativas anchas se usa el menú lateral', () {
      expect(
        homeNavigationMode(isWeb: false, width: kHomeRailBreakpoint),
        HomeNavigationMode.rail,
      );
      expect(
        homeNavigationMode(isWeb: false, width: 1400),
        HomeNavigationMode.extendedRail,
      );
    });
  });
}
