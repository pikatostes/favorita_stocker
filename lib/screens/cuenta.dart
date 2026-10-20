import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/app_logo.dart';

/// Datos del usuario conectado y acciones de cuenta.
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final repeat = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Contraseña actual'),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Introduce tu contraseña actual.'
                    : null,
              ),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nueva contraseña'),
                validator: (value) => (value ?? '').length < 6
                    ? 'Debe tener al menos 6 caracteres.'
                    : null,
              ),
              TextFormField(
                controller: repeat,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Repetir contraseña'),
                validator: (value) =>
                    value != next.text ? 'Las contraseñas no coinciden.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final error = await AuthController.i.changePassword(
      currentPassword: current.text,
      newPassword: next.text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Contraseña actualizada.'),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthController.i.logout();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AuthController.i,
        builder: (context, _) {
          final user = AuthController.i.user;
          if (user == null) {
            return const Center(child: Text('No hay una sesión iniciada.'));
          }
          final role = user.role;
          return Scaffold(
            appBar: AppBar(title: const AppLogo()),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          child: Text(
                            user.initial,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(user.email),
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.work_outline, size: 18),
                          label: Text(
                            role == null
                                ? 'Sin puesto asignado'
                                : '${role.name} · ${role.floor.label}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('Días que puede trabajar'),
                        subtitle: Text(user.workingDaysLabel),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_open_outlined),
                        title: const Text('Puede abrir'),
                        subtitle: Text(user.opener ? 'Sí' : 'No'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Estado'),
                        subtitle: Text(user.active ? 'Activo' : 'Inactivo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: () => _changePassword(context),
                  icon: const Icon(Icons.password),
                  label: const Text('Cambiar contraseña'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          );
        },
      );
}
