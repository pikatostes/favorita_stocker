import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../app_design.dart';
import '../auth_controller.dart';
import '../db.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_ui.dart';
import '../widgets/palette_picker.dart';
import '../widgets/user_avatar.dart';

/// Datos del usuario conectado y acciones de cuenta.
class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _avatarBusy = false;

  /// Reduce y convierte la imagen elegida a JPEG para que el bucket no crezca
  /// y la carga sea rápida en móvil y web.
  Uint8List _prepareAvatar(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const FormatException('El archivo no es una imagen válida.');
    }
    final oriented = img.bakeOrientation(decoded);
    final largest = math.max(oriented.width, oriented.height);
    final resized = largest <= 512
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 512 : null,
            height: oriented.height > oriented.width ? 512 : null,
            interpolation: img.Interpolation.average,
          );
    return img.encodeJpg(resized, quality: 85);
  }

  Future<void> _pickAvatar() async {
    if (AuthController.i.user == null || _avatarBusy) return;
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo abrir el selector de imágenes.',
          tone: AppTone.danger,
        );
      }
      return;
    }
    if (picked == null) return;

    setState(() => _avatarBusy = true);
    try {
      final raw = await picked.readAsBytes();
      final bytes = _prepareAvatar(raw);
      await Db.i.updateOwnAvatar(bytes: bytes);
      await AuthController.i.refresh();
      if (mounted) {
        showAppSnack(
          context,
          'Foto de perfil actualizada.',
          tone: AppTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo actualizar la foto: ${describeDbError(error)}',
          tone: AppTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_avatarBusy) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Quitar foto de perfil',
      message: '¿Quieres quitar tu foto? Se mostrará tu inicial.',
      confirmLabel: 'Quitar',
    );
    if (!ok || !mounted) return;

    setState(() => _avatarBusy = true);
    try {
      await Db.i.removeOwnAvatar();
      await AuthController.i.refresh();
      if (mounted) {
        showAppSnack(
          context,
          'Foto de perfil eliminada.',
          tone: AppTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo quitar la foto: ${describeDbError(error)}',
          tone: AppTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

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
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        user: user,
                        radius: 36,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        textStyle: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Tooltip(
                          message: user.avatarPath == null
                              ? 'Añadir foto de perfil'
                              : 'Cambiar foto de perfil',
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _avatarBusy ? null : _pickAvatar,
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: _avatarBusy
                                    ? SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.photo_camera_outlined,
                                        size: 17,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.avatarPath != null)
                    TextButton.icon(
                      onPressed: _avatarBusy ? null : _removeAvatar,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Quitar foto'),
                    )
                  else
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
                    const Divider(height: 1),
                    const PaletteTile(),
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
