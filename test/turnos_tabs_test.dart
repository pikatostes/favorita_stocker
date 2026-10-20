import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/turnos.dart';
import 'package:stock_bar/shifts.dart';

void main() {
  test('los empleados no ven la pestaña Puestos', () {
    final tabs = visibleTurnoTabs(UserRole.employee);

    expect(tabs, [TurnoTab.schedule, TurnoTab.users]);
    expect(tabs.map((tab) => tab.label), isNot(contains('Puestos')));
  });

  test('los administradores ven Horario, Usuarios y Puestos', () {
    expect(visibleTurnoTabs(UserRole.admin), TurnoTab.values);
  });
}
