import '../../../shifts.dart';

/// Resumen de otro usuario tal y como lo ve un empleado: rol de acceso, puesto
/// habitual y estado. El nombre y los apellidos van en el título de la fila.
///
/// Deja fuera el email, los días de trabajo y si puede abrir, que son datos de
/// gestión reservados al administrador.
String employeeUserSummary(AppUser user) {
  final jobRole = user.jobRole?.name ?? 'Sin puesto';
  return '${user.role.label} · $jobRole · ${user.active ? 'Activo' : 'Inactivo'}';
}
