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
}
