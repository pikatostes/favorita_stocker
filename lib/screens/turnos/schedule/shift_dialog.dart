import 'package:flutter/material.dart';

import '../../../formats.dart';
import '../../../shifts.dart';
import '../../../widgets/app_ui.dart';

/// Diálogo de edición de un turno: horas, planta, puesto, estado y nota.
class ShiftDialog extends StatefulWidget {
  final Shift shift;

  const ShiftDialog({super.key, required this.shift});

  @override
  State<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<ShiftDialog> {
  late int _start = widget.shift.startMin;
  late int _end = widget.shift.endMin;
  late ShiftStatus _status = widget.shift.status;
  late Floor _floor = widget.shift.position == JobPosition.manteni
      ? Floor.plantaBaja
      : widget.shift.floor;
  late JobPosition _position = widget.shift.position;
  late final TextEditingController _note =
      TextEditingController(text: widget.shift.note);

  /// El puesto de mantenimiento trabaja siempre en planta baja.
  bool get _isMaintenance => _position == JobPosition.manteni;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (!mounted || picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _save() {
    if (_start == _end) {
      showAppSnack(context, 'La entrada y la salida no pueden ser iguales.');
      return;
    }
    Navigator.pop(
      context,
      Shift(
        id: widget.shift.id,
        date: widget.shift.date,
        userId: widget.shift.userId,
        userName: widget.shift.userName,
        position: _position,
        positionName: _position.label,
        floor: _isMaintenance ? Floor.plantaBaja : _floor,
        startMin: _start,
        endMin: _end,
        breakMin: breakMinutesFor(startMin: _start, endMin: _end),
        status: _status,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = shiftDurationMinutes(_start, _end);
    final breakMin = breakMinutesFor(startMin: _start, endMin: _end);
    final worked = duration - breakMin;
    return AlertDialog(
      title: const Text('Editar turno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.shift.userName} · ${widget.shift.positionName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              formatLongDateIso(widget.shift.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: true),
                    icon: const Icon(Icons.login),
                    label: Text(formatMinutes(_start)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: false),
                    icon: const Icon(Icons.logout),
                    label: Text(formatMinutes(_end)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Duración: ${formatHours(duration)} · '
              'Descanso: ${breakMin == 0 ? 'ninguno' : '$breakMin min'} · '
              'Trabajado: ${formatHours(worked)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<JobPosition>(
              initialValue: _position,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Puesto'),
              items: [
                for (final position in JobPosition.values)
                  DropdownMenuItem<JobPosition>(
                    value: position,
                    child: Text(position.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _position = value;
                  if (value == JobPosition.manteni) {
                    _floor = Floor.plantaBaja;
                  }
                });
              },
            ),
            DropdownButtonFormField<Floor>(
              initialValue: _floor,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Planta',
                helperText: _isMaintenance
                    ? 'Manteni trabaja siempre en planta baja.'
                    : null,
              ),
              items: [
                for (final floor in Floor.values)
                  DropdownMenuItem<Floor>(
                    value: floor,
                    enabled: !_isMaintenance || floor == Floor.plantaBaja,
                    child: Text(floor.label),
                  ),
              ],
              onChanged: _isMaintenance
                  ? null
                  : (value) {
                      if (value != null) setState(() => _floor = value);
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ShiftStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: [
                for (final status in ShiftStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota del turno'),
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
}
