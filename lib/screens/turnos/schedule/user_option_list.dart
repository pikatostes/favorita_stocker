import 'package:flutter/material.dart';

import '../../../shifts.dart';
import '../../../widgets/user_avatar.dart';

/// Estado de un usuario dentro de un selector de personas para un turno.
class UserOption {
  final AppUser user;

  /// Si puede seleccionarse. Se desactiva si no tiene puesto o si ya tiene un
  /// turno que se solapa con la franja elegida.
  final bool enabled;

  /// Motivo o datos que se muestran bajo el nombre.
  final String detail;

  /// Si [detail] describe un conflicto (se pinta con color de aviso).
  final bool conflict;

  const UserOption({
    required this.user,
    required this.enabled,
    required this.detail,
    this.conflict = false,
  });
}

/// Lista de usuarios con casilla de selección.
///
/// La usan los diálogos de nueva franja y de asignar personas a una franja
/// existente, para que ambos muestren el mismo aspecto y los mismos avisos de
/// solape.
class UserOptionList extends StatelessWidget {
  final List<UserOption> options;
  final Set<int> selected;
  final ValueChanged<int> onChanged;

  const UserOptionList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No hay usuarios disponibles.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final user = option.user;
        final id = user.id;
        return CheckboxListTile(
          value: id != null && selected.contains(id),
          onChanged: option.enabled && id != null ? (_) => onChanged(id) : null,
          controlAffinity: ListTileControlAffinity.trailing,
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: UserAvatar(user: user),
          title: Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            option.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: option.conflict
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
