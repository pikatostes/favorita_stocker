import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../db.dart';
import '../../../incidents.dart';
import '../../../widgets/app_ui.dart';
import '../../incidents.dart';

/// Resumen de incidencias para Inicio.
///
/// Se carga aparte del resto del panel para que un fallo del listado no rompa
/// el Inicio. Cualquier usuario puede abrir el listado completo y declarar una
/// incidencia desde el botón de acción de esa pantalla.
class IncidentsCard extends StatefulWidget {
  const IncidentsCard({super.key});

  @override
  State<IncidentsCard> createState() => _IncidentsCardState();
}

class _IncidentsCardState extends State<IncidentsCard> {
  late Future<List<Incident>> _future = Db.i.incidents();

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = Db.i.incidents();
    });
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  Future<void> _openList({bool startNew = false}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncidentsScreen(startNew: startNew),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Incident>>(
      future: _future,
      builder: (context, snapshot) {
        // Es información secundaria: si aún no ha cargado o falla, no se
        // muestra nada para no dejar un hueco roto en el panel.
        if (!snapshot.hasData) return const SizedBox.shrink();

        final incidents = snapshot.data!;
        final open = incidents
            .where((incident) => incident.status == IncidentStatus.open)
            .toList(growable: false);
        final inProgress = incidents
            .where((incident) => incident.status == IncidentStatus.inProgress)
            .toList(growable: false);
        final active = [...open, ...inProgress].take(3).toList(growable: false);
        final summary = incidents.isEmpty
            ? 'Sin incidencias registradas'
            : '${open.length} abierta${open.length == 1 ? '' : 's'} · '
                '${inProgress.length} en proceso';

        return AppSectionCard(
          icon: Icons.report_problem_outlined,
          title: 'Incidencias',
          trailing: TextButton.icon(
            onPressed: () => _openList(),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: const Text('Ver todas'),
          ),
          children: [
            MutedText(summary),
            const SizedBox(height: AppSpacing.sm),
            if (active.isEmpty)
              Text(
                'Todo en orden. No hay incidencias activas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final incident in active)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        incident.category.icon,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incident.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${incident.floor.label} · '
                              '${incident.category.label}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        label: incident.status.label,
                        tone: incident.status == IncidentStatus.open
                            ? AppTone.warning
                            : AppTone.info,
                        dense: true,
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => _openList(startNew: true),
                icon: const Icon(Icons.add_alert_outlined, size: 18),
                label: const Text('Reportar incidencia'),
              ),
            ),
          ],
        );
      },
    );
  }
}
