import 'package:flutter/material.dart';

import '../../../auth_controller.dart';
import '../../../db.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/user_avatar.dart';
import 'user_form_dialog.dart';
import 'user_info_dialog.dart';
import 'user_summary.dart';

/// Pestaña Usuarios: listado del equipo y gestión de altas y estados.
///
/// El administrador ve los datos de gestión (email, días, apertura), edita y
/// activa/desactiva. El empleado solo ve el resumen público de cada persona.
class UsersTab extends StatefulWidget {
  final bool isAdmin;

  const UsersTab({super.key, required this.isAdmin});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  late Future<List<AppUser>> _future = Db.i.users(includeInactive: true);

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = Db.i.users(includeInactive: true);
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

  Future<void> _edit([AppUser? user]) async {
    if (!widget.isAdmin) return;
    final roles = await Db.i.roles();
    if (!mounted) return;
    final result = await showDialog<UserFormResult>(
      context: context,
      builder: (_) => UserFormDialog(user: user, roles: roles),
    );
    if (result == null) return;
    try {
      if (user == null) {
        await Db.i.addUser(result.user, password: result.password!);
      } else {
        await Db.i.updateUser(result.user, password: result.password);
        await AuthController.i.refresh();
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo guardar el usuario: ${describeDbError(error)}',
      );
    }
  }

  Future<void> _toggle(AppUser user) async {
    if (!widget.isAdmin) return;
    try {
      await Db.i.setUserActive(user.id!, !user.active);
      await AuthController.i.refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo cambiar el estado: ${describeDbError(error)}',
      );
    }
  }

  Future<void> _showInfo(AppUser user) => showDialog<void>(
        context: context,
        builder: (_) => UserInfoDialog(user: user),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<List<AppUser>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar los usuarios: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!;
            if (users.isEmpty) {
              return Center(
                child: Text(
                  widget.isAdmin
                      ? 'Añade tu primer usuario con +'
                      : 'No hay usuarios.',
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final jobRole = user.jobRole;
                return ListTile(
                  leading: UserAvatar(user: user),
                  title: Text(
                    user.fullName,
                    style: user.active
                        ? null
                        : const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          ),
                  ),
                  subtitle: widget.isAdmin
                      ? Text(
                          '${user.email}\n'
                          '${user.role.label}'
                          ' · ${jobRole == null ? 'Sin puesto' : '${jobRole.name} · ${jobRole.floor.label}'}'
                          ' · ${user.workingDaysLabel}'
                          '${user.opener ? ' · Puede abrir' : ''}',
                        )
                      // Los empleados solo ven nombre, rol de acceso, puesto y
                      // estado: el email, los días y la apertura son datos de
                      // gestión que no necesitan.
                      : Text(employeeUserSummary(user)),
                  isThreeLine: widget.isAdmin,
                  trailing: widget.isAdmin
                      ? Switch(
                          value: user.active,
                          onChanged: (_) => _toggle(user),
                        )
                      : null,
                  onTap: () => widget.isAdmin ? _edit(user) : _showInfo(user),
                );
              },
            );
          },
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton(
                onPressed: () => _edit(),
                child: const Icon(Icons.person_add),
              )
            : null,
      );
}
