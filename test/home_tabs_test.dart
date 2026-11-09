import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/app_design.dart';
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

  group('navegación adaptativa por ancho', () {
    test('móvil usa barra inferior, también en web', () {
      expect(
        homeNavigationMode(isWeb: false, width: 375),
        HomeNavigationMode.bottomBar,
      );
      expect(
        homeNavigationMode(isWeb: true, width: 390),
        HomeNavigationMode.bottomBar,
      );
      expect(
        homeNavigationMode(isWeb: true, width: AppBreakpoints.mobileMax - 1),
        HomeNavigationMode.bottomBar,
      );
    });

    test('tablet usa el rail lateral', () {
      expect(
        homeNavigationMode(isWeb: true, width: AppBreakpoints.tabletMin),
        HomeNavigationMode.rail,
      );
      expect(
        homeNavigationMode(isWeb: false, width: 768),
        HomeNavigationMode.rail,
      );
      expect(
        homeNavigationMode(isWeb: true, width: AppBreakpoints.desktopMin - 1),
        HomeNavigationMode.rail,
      );
    });

    test('escritorio usa el sidebar', () {
      expect(
        homeNavigationMode(isWeb: true, width: AppBreakpoints.desktopMin),
        HomeNavigationMode.sidebar,
      );
      expect(
        homeNavigationMode(isWeb: false, width: 1440),
        HomeNavigationMode.sidebar,
      );
    });
  });
}
