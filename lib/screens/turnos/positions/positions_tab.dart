import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../shifts.dart';
import '../../../widgets/shift_ui.dart';

/// Pestaña Puestos: catálogo fijo de puestos y plantas del local.
///
/// Los puestos no se crean ni se borran desde la app: solo existen `camarero`
/// y `manteni`. La planta habitual de cada persona se elige en su ficha de
/// usuario y el puesto del turno se puede cambiar al editarlo.
class PositionsTab extends StatelessWidget {
  const PositionsTab({super.key});

  static String _positionDescription(JobPosition position) =>
      switch (position) {
        JobPosition.camarero => 'Atiende las mesas y el servicio de barra.',
        JobPosition.manteni =>
          'Tareas de mantenimiento. Siempre se asigna a planta baja.',
      };

  static IconData _positionIcon(JobPosition position) => switch (position) {
        JobPosition.camarero => Icons.restaurant_outlined,
        JobPosition.manteni => Icons.build_outlined,
      };

  static String _floorDescription(Floor floor) => switch (floor) {
        Floor.plantaBaja => 'Barra, mesas y mantenimiento.',
        Floor.karaoke => 'Sala de karaoke.',
        Floor.terraza => 'Zona exterior.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Puestos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El catálogo es fijo. Cada usuario tiene un puesto habitual y '
              'puede cambiarse en su ficha; el turno conserva el puesto con '
              'el que se generó y se puede editar después.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final position in JobPosition.values)
              Card(
                child: ListTile(
                  leading: Icon(_positionIcon(position)),
                  title: Text(position.label),
                  subtitle: Text(_positionDescription(position)),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Plantas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Al generar el horario, cada persona se asigna primero a su '
              'planta habitual. Manteni siempre trabaja en planta baja.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final floor in Floor.values)
              Card(
                child: ListTile(
                  leading: Icon(floorIcon(floor)),
                  title: Text(floor.label),
                  subtitle: Text(_floorDescription(floor)),
                ),
              ),
          ],
        ),
      );
}
