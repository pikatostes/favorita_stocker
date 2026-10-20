import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/home.dart';
import 'package:stock_bar/shifts.dart';

void main() {
  test('los empleados no ven Calendario ni Productos', () {
    final tabs = visibleHomeTabs(UserRole.employee);

    expect(
      tabs,
      [HomeTab.list, HomeTab.forecast, HomeTab.shifts, HomeTab.account],
    );
    expect(tabs.map((tab) => tab.label), isNot(contains('Calendario')));
    expect(tabs.map((tab) => tab.label), isNot(contains('Productos')));
  });

  test('los administradores ven una única pestaña Admin', () {
    final tabs = visibleHomeTabs(UserRole.admin);

    expect(tabs, HomeTab.values);
    expect(
      tabs.map((tab) => tab.label),
      ['Lista', 'Previsión', 'Turnos', 'Admin', 'Cuenta'],
    );
  });
}
