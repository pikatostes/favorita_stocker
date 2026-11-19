import 'package:flutter/material.dart';

import '../../../auth.dart';
import '../../../auth_controller.dart';
import '../../../shifts.dart';

/// Resultado del formulario de usuario.
///
/// [password] solo viene informado cuando se ha escrito una contraseña nueva;
/// al editar sin cambiarla se mantiene la actual.
typedef UserFormResult = ({AppUser user, String? password});

/// Formulario de alta y edición de usuarios (solo administradores).
class UserFormDialog extends StatefulWidget {
  final AppUser? user;
  final List<JobRole> roles;

  const UserFormDialog({super.key, required this.user, required this.roles});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _surname =
      TextEditingController(text: widget.user?.surname ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();
  JobRole? _jobRole;
  late UserRole _accessRole = widget.user?.role ?? UserRole.employee;
  late bool _active = widget.user?.active ?? true;
  late bool _opener = widget.user?.opener ?? false;
  late final Set<int> _workingDays = {...?widget.user?.workingDays};
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // El usuario trae una instancia de JobRole distinta a la de la lista de
    // puestos. El DropdownButton compara por identidad, así que hay que usar
    // exactamente el objeto que aparece en sus items.
    _jobRole = roleFromList(widget.roles, widget.user?.jobRole);
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final password = _password.text;
    Navigator.pop<UserFormResult>(
      context,
      (
        user: AppUser(
          id: widget.user?.id,
          name: _name.text.trim(),
          surname: _surname.text.trim(),
          email: _email.text.trim().toLowerCase(),
          jobRole: _jobRole,
          role: _accessRole,
          active: _active,
          opener: _opener,
          workingDays: _workingDays,
        ),
        password: password.isEmpty ? null : password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    final canAssignRole = AuthController.i.user?.role == UserRole.admin;
    return AlertDialog(
      title: Text(editing ? 'Editar usuario' : 'Nuevo usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
              TextFormField(
                controller: _surname,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    isValidEmail(value ?? '') ? null : 'El email no es válido.',
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: editing ? 'Nueva contraseña' : 'Contraseña',
                  helperText: editing
                      ? 'Déjala vacía para mantener la actual.'
                      : 'Mínimo 6 caracteres.',
                  suffixIcon: IconButton(
                    tooltip:
                        _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (!editing && password.isEmpty) {
                    return 'La contraseña es obligatoria.';
                  }
                  if (password.isNotEmpty && password.length < 6) {
                    return 'Debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              if (canAssignRole)
                DropdownButtonFormField<UserRole>(
                  initialValue: _accessRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rol de acceso'),
                  items: [
                    for (final role in UserRole.values)
                      DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _accessRole = value ?? UserRole.employee,
                  ),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rol de acceso'),
                  subtitle: Text(_accessRole.label),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
              DropdownButtonFormField<JobRole>(
                initialValue: _jobRole,
                isExpanded: true,
                hint: const Text('Sin puesto'),
                decoration: const InputDecoration(labelText: 'Puesto habitual'),
                items: [
                  for (final role in widget.roles)
                    DropdownMenuItem<JobRole>(
                      value: role,
                      child: Text(
                        '${role.name} · ${role.floor.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _jobRole = value),
              ),
              if (_jobRole != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _jobRole = null),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Dejar sin puesto'),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activo'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Puede abrir'),
                subtitle: const Text('Puede abrir el bar o su planta.'),
                value: _opener,
                onChanged: (value) => setState(() => _opener = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Días que puede trabajar',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _workingDays.isEmpty
                      ? 'Sin selección: cualquier día.'
                      : 'Solo: ${(_workingDays.toList()..sort()).map(weekdayShort).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(weekdayShort(day)),
                      selected: _workingDays.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _workingDays.add(day);
                        } else {
                          _workingDays.remove(day);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
