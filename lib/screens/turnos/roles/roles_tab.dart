import 'package:flutter/material.dart';

import '../../../db.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/shift_ui.dart';
import 'role_dialog.dart';

/// Pestaña Puestos: catálogo de puestos por planta (solo administradores).
class RolesTab extends StatefulWidget {
  const RolesTab({super.key});

  @override
  State<RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<RolesTab> {
  late Future<List<JobRole>> _future = Db.i.roles();
  late final VoidCallback _stopWatching;

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = Db.i.roles();
    });
  }

  @override
  void initState() {
    super.initState();
    _stopWatching = Db.i.watchTables(const {'job_role'}, _reload);
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  Future<void> _edit([JobRole? role]) async {
    final result = await showDialog<JobRole>(
      context: context,
      builder: (_) => RoleDialog(role: role),
    );
    if (result == null) return;
    try {
      if (role == null) {
        await Db.i.addRole(result);
      } else {
        await Db.i.updateRole(result);
      }
    } on StateError catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message.toString());
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, 'No se pudo guardar el puesto: $error');
    }
  }

  Future<void> _delete(JobRole role) async {
    final ok = await showConfirmDialog(
      context,
      title: '¿Borrar ${role.name}?',
      message: 'Solo se puede borrar si no tiene usuarios asignados.',
      confirmLabel: 'Borrar',
    );
    if (!ok) return;
    try {
      await Db.i.deleteRole(role.id!);
    } on StateError catch (error) {
      if (!mounted) return;
      showAppSnack(context, error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<JobRole>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los puestos: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final roles = snapshot.data!;
            if (roles.isEmpty) {
              return const Center(
                child: Text('Crea tu primer puesto con +'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: roles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final role = roles[index];
                return ListTile(
                  leading: Icon(floorIcon(role.floor)),
                  title: Text(role.name),
                  subtitle: Text(
                    '${role.floor.label}'
                    '${role.note.trim().isEmpty ? '' : ' · ${role.note.trim()}'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(role),
                  ),
                  onTap: () => _edit(role),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _edit(),
          child: const Icon(Icons.work_outline),
        ),
      );
}
