import 'package:flutter/material.dart';

import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';

/// Diálogo de alta y edición de un puesto de trabajo.
class RoleDialog extends StatefulWidget {
  final JobRole? role;

  const RoleDialog({super.key, required this.role});

  @override
  State<RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<RoleDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.role?.name ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.role?.note ?? '');
  late Floor _floor = widget.role?.floor ?? Floor.plantaBaja;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'El nombre del puesto es obligatorio.');
      return;
    }
    Navigator.pop(
      context,
      JobRole(
        id: widget.role?.id,
        name: name,
        floor: _floor,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.role == null ? 'Nuevo puesto' : 'Editar puesto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              DropdownButtonFormField<Floor>(
                initialValue: _floor,
                decoration: const InputDecoration(labelText: 'Planta'),
                items: [
                  for (final floor in Floor.values)
                    DropdownMenuItem(value: floor, child: Text(floor.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _floor = value);
                },
              ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Nota del puesto (opcional)',
                  hintText: 'Evento privado en el karaoke',
                ),
              ),
            ],
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
