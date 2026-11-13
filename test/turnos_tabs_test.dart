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

  test('el resumen para empleados solo muestra rol, puesto y estado', () {
    const user = AppUser(
      name: 'Lucía',
      surname: 'Pérez',
      email: 'lucia@favorita.local',
      role: UserRole.admin,
      active: false,
      opener: true,
      workingDays: {1, 2},
      jobRole: JobRole(
        id: 1,
        name: 'Camarero',
        floor: Floor.plantaBaja,
      ),
    );

    expect(employeeUserSummary(user), 'Administrador · Camarero · Inactivo');
    // Ni email, ni días de trabajo, ni si puede abrir.
    expect(employeeUserSummary(user), isNot(contains('@')));
    expect(employeeUserSummary(user), isNot(contains('Puede abrir')));
  });

  test('sin puesto habitual el resumen lo indica', () {
    const user = AppUser(name: 'Ana', active: true);

    expect(employeeUserSummary(user), 'Empleado · Sin puesto · Activo');
  });
}
