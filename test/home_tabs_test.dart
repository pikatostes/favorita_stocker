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

  test('los administradores ven todas las pestañas', () {
    expect(visibleHomeTabs(UserRole.admin), HomeTab.values);
  });
}
