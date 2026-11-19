import '../../shifts.dart';

/// Pestañas internas de Turnos. [roles] (Puestos) solo está disponible para
/// administradores.
enum TurnoTab {
  schedule('Horario'),
  users('Usuarios'),
  roles('Puestos', adminOnly: true);

  final String label;
  final bool adminOnly;

  const TurnoTab(this.label, {this.adminOnly = false});
}

/// Pestañas internas de Turnos visibles para [role].
List<TurnoTab> visibleTurnoTabs(UserRole role) => [
      for (final tab in TurnoTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];
