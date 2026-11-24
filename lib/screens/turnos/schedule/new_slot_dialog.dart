import 'package:flutter/material.dart';

import '../../../formats.dart';
import '../../../schedule.dart';
import '../../../shifts.dart';
import 'shift_overlap.dart';
import 'user_option_list.dart';

/// Diálogo para crear una franja horaria nueva en una planta.
///
/// Una franja no existe por sí sola: al guardar se crean los turnos de las
/// personas seleccionadas. Si no se selecciona a nadie no se guarda nada, y si
/// después se borran todos sus turnos, la franja desaparece del horario.
class NewSlotDialog extends StatefulWidget {
  final String date;
  final Floor floor;
  final List<AppUser> users;
  final List<Shift> dayShifts;

  const NewSlotDialog({
    super.key,
    required this.date,
    required this.floor,
    required this.users,
    required this.dayShifts,
  });

  @override
  State<NewSlotDialog> createState() => _NewSlotDialogState();
}

class _NewSlotDialogState extends State<NewSlotDialog> {
  int _start = Schedule.openHour * 60;
  int _end = Schedule.peakHour * 60;
  final Set<int> _selected = {};
  bool _showError = false;

  int get _duration => shiftDurationMinutes(_start, _end);
  int get _break => breakMinutesFor(startMin: _start, endMin: _end);

  AppUser? _userById(int id) {
    for (final user in widget.users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Shift? _conflictFor(AppUser user) {
    final id = user.id;
    if (id == null || _start == _end) return null;
    return firstOverlappingShift(
      widget.dayShifts,
      startMin: _start,
      endMin: _end,
      userId: id,
    );
  }

  /// Al cambiar las horas, quita de la selección a quien pase a tener un
  /// turno que se solape con la nueva franja.
  void _pruneConflicts() {
    _selected.removeWhere((id) {
      final user = _userById(id);
      return user == null || _conflictFor(user) != null;
    });
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
      _pruneConflicts();
      _showError = false;
    });
  }

  UserOption _optionFor(AppUser user) {
    final position = user.jobPosition;
    if (user.id == null || position == null) {
      return UserOption(
        user: user,
        enabled: false,
        detail: 'Sin puesto asignado',
        conflict: true,
      );
    }
    final conflict = _conflictFor(user);
    if (conflict != null) {
      return UserOption(
        user: user,
        enabled: false,
        detail: 'Ya tiene turno ${conflict.timeLabel} · '
            '${conflict.floor.label}',
        conflict: true,
      );
    }
    return UserOption(
      user: user,
      enabled: true,
      detail: '${position.label} · ${user.effectiveFloor.label}',
    );
  }

  void _save() {
    if (_start == _end || _selected.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final selectedUsers = [
      for (final user in widget.users)
        if (user.id != null && _selected.contains(user.id)) user,
    ];
    Navigator.pop<List<Shift>>(
      context,
      [for (final user in selectedUsers) _buildShift(user)],
    );
  }

  Shift _buildShift(AppUser user) => Shift(
        date: widget.date,
        userId: user.id!,
        userName: user.fullName,
        position: user.jobPosition!,
        positionName: user.jobPosition!.label,
        floor: widget.floor,
        startMin: _start,
        endMin: _end,
        breakMin: breakMinutesFor(startMin: _start, endMin: _end),
        status: ShiftStatus.draft,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [for (final user in widget.users) _optionFor(user)];
    final errorStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );

    return AlertDialog(
      title: Text('Nueva franja · ${widget.floor.label}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatLongDateIso(widget.date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                'Duración: ${formatHours(_duration)} · '
                'Descanso: ${_break == 0 ? 'ninguno' : '$_break min'}',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 24),
              Text(
                'Personas (mínimo 1)',
                style: theme.textTheme.labelLarge,
              ),
              if (_start == _end && _showError)
                Text('La entrada y la salida no pueden ser iguales.',
                    style: errorStyle)
              else if (_selected.isEmpty && _showError)
                Text('Selecciona al menos una persona.', style: errorStyle),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: UserOptionList(
                  options: options,
                  selected: _selected,
                  onChanged: (id) => setState(() {
                    if (_selected.contains(id)) {
                      _selected.remove(id);
                    } else {
                      _selected.add(id);
                    }
                    _showError = false;
                  }),
                ),
              ),
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_selected.length} '
                    'persona${_selected.length == 1 ? '' : 's'} seleccionada'
                    '${_selected.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
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
        FilledButton(onPressed: _save, child: const Text('Crear franja')),
      ],
    );
  }
}
