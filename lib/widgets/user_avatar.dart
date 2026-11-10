import 'package:flutter/material.dart';

import '../db.dart';
import '../shifts.dart';

/// Avatar de un usuario con su foto de perfil o, si no tiene, su inicial.
///
/// La foto se resuelve con la ruta guardada en [AppUser.avatarPath]; si el
/// archivo no existe o falla la red, se muestra la inicial sin romper la UI.
class UserAvatar extends StatelessWidget {
  final AppUser? user;

  /// Ruta explícita cuando no se tiene el [AppUser] completo (por ejemplo, en
  /// la línea temporal de turnos).
  final String? path;

  /// Nombre para calcular la inicial cuando no hay [user].
  final String name;

  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;

  const UserAvatar({
    super.key,
    this.user,
    this.path,
    this.name = '',
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        name.trim().isNotEmpty ? name.trim() : (user?.fullName ?? '');
    final initial =
        displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();
    final avatarPath = (path ?? user?.avatarPath)?.trim();
    final background =
        backgroundColor ?? theme.colorScheme.surfaceContainerHigh;
    final foreground = foregroundColor ?? theme.colorScheme.onSurface;
    final style = (textStyle ?? theme.textTheme.labelLarge)?.copyWith(
      fontWeight: FontWeight.w700,
    );

    if (avatarPath == null || avatarPath.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: background,
        foregroundColor: foreground,
        child: Text(initial, style: style),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundColor: foreground,
      foregroundImage: NetworkImage(Db.i.avatarPublicUrl(avatarPath)),
      // Al fallar la imagen se conserva la inicial del child.
      onForegroundImageError: (_, __) {},
      child: Text(initial, style: style),
    );
  }
}
