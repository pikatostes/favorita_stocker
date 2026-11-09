import 'package:flutter/material.dart';

import '../app_design.dart';
import '../auth_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_ui.dart';

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
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nueva contraseña'),
                validator: (value) => (value ?? '').length < 6
                    ? 'Debe tener al menos 6 caracteres.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
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
    showAppSnack(
      context,
      error ?? 'Contraseña actualizada.',
      tone: error == null ? AppTone.success : AppTone.danger,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres salir de tu cuenta?',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok) await AuthController.i.logout();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AuthController.i,
        builder: (context, _) {
          final user = AuthController.i.user;
          if (user == null) {
            return const AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'No hay una sesión iniciada',
            );
          }
          final jobRole = user.jobRole;

          final profile = Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: Text(
                      user.initial,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.work_outline, size: 17),
                        label: Text(
                          jobRole == null
                              ? 'Sin puesto asignado'
                              : '${jobRole.name} · ${jobRole.floor.label}',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.shield_outlined, size: 17),
                        label: Text(user.role.label),
                      ),
                      StatusPill(
                        label: user.active ? 'Activo' : 'Inactivo',
                        icon: user.active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        tone: user.active ? AppTone.success : AppTone.neutral,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          final settings = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('Días que puede trabajar'),
                      subtitle: Text(user.workingDaysLabel),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_open_outlined),
                      title: const Text('Puede abrir'),
                      subtitle: Text(user.opener ? 'Sí' : 'No'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Estado'),
                      subtitle: Text(user.active ? 'Activo' : 'Inactivo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: () => _changePassword(context),
                icon: const Icon(Icons.password),
                label: const Text('Cambiar contraseña'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= AppBreakpoints.twoColumnContent;
                final horizontal =
                    constraints.maxWidth >= AppBreakpoints.desktopMin
                        ? AppSpacing.xl
                        : AppSpacing.lg;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.md,
                    horizontal,
                    AppSpacing.xl,
                  ),
                  child: AppContentFrame(
                    maxWidth: 1040,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppPageHeader(
                          eyebrow: 'Sesión',
                          title: 'Mi cuenta',
                          subtitle: 'Datos del perfil y opciones de acceso.',
                          leading: AppLogo(height: 26),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: profile),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(flex: 3, child: settings),
                            ],
                          )
                        else ...[
                          profile,
                          const SizedBox(height: AppSpacing.lg),
                          settings,
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}
