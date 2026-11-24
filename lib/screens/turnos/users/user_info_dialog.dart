import 'package:flutter/material.dart';

import '../../../shifts.dart';
import '../../../widgets/user_avatar.dart';

/// Ficha de solo lectura que se muestra a los empleados al tocar un usuario.
///
/// Solo incluye los datos que un empleado puede ver del resto del equipo:
/// nombre (en el título), rol de acceso, puesto y estado.
class UserInfoDialog extends StatelessWidget {
  final AppUser user;

  const UserInfoDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final position = user.jobPosition;
    return AlertDialog(
      title: Row(
        children: [
          UserAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(child: Text(user.fullName)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              icon: Icons.shield_outlined,
              label: 'Rol de acceso',
              value: user.role.label,
            ),
            _InfoRow(
              icon: Icons.work_outline,
              label: 'Puesto habitual',
              value: position == null ? 'Sin puesto' : position.label,
            ),
            _InfoRow(
              icon: Icons.storefront_outlined,
              label: 'Planta habitual',
              value: user.effectiveFloor.label,
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Estado',
              value: user.active ? 'Activo' : 'Inactivo',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      );
}
