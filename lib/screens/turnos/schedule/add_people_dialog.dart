import 'package:flutter/material.dart';

import '../../../formats.dart';
import '../../../shifts.dart';
import 'shift_overlap.dart';
import 'user_option_list.dart';

/// Una franja horaria existente y los turnos que la forman.
class _Slot {
  final int startMin;
  final int endMin;
  final List<Shift> shifts;

  const _Slot(this.startMin, this.endMin, this.shifts);

  String get label => '${formatMinutes(startMin)}–${formatMinutes(endMin)} · '
      '${shifts.length} pers.';

  bool contains(AppUser user) => shifts.any((s) => s.userId == user.id);
}

/// Diálogo para asignar personas a una franja ya existente de la planta.
///
/// Muestra todas las personas activas y desactiva a quien ya tiene un turno
/// que se solapa con la franja elegida. Se permite asignar a alguien que ese
/// día tenga otro turno en horas distintas (por ejemplo, 17:00–20:00 y luego
/// 21:00–03:00).
class AddPeopleDialog extends StatefulWidget {
  final String date;
  final Floor floor;
  final List<AppUser> users;

  /// Turnos de la planta actual: definen las franjas que se pueden elegir.
  final List<Shift> floorShifts;

  /// Todos los turnos del día, para detectar solapes en cualquier planta.
  final List<Shift> dayShifts;

  const AddPeopleDialog({
    super.key,
    required this.date,
    required this.floor,
    required this.users,
    required this.floorShifts,
    required this.dayShifts,
  });

  @override
  State<AddPeopleDialog> createState() => _AddPeopleDialogState();
}

class _AddPeopleDialogState extends State<AddPeopleDialog> {
  final Set<int> _selected = {};
  late final List<_Slot> _slots = _buildSlots();
  int _slotIndex = 0;
  bool _showError = false;

  _Slot get _slot => _slots[_slotIndex];

  List<_Slot> _buildSlots() {
    final groups = <(int, int), List<Shift>>{};
    for (final shift in widget.floorShifts) {
      groups.putIfAbsent((shift.startMin, shift.endMin), () => []).add(shift);
    }
    final slots = [
      for (final entry in groups.entries)
        _Slot(entry.key.$1, entry.key.$2, entry.value),
    ];
    slots.sort((a, b) {
      final byStart = nightAxisMinute(a.startMin) - nightAxisMinute(b.startMin);
      return byStart != 0 ? byStart : a.endMin - b.endMin;
    });
    return slots;
  }

  List<Shift> _otherShifts(AppUser user) => [
        for (final shift in widget.dayShifts)
          if (shift.userId == user.id) shift,
      ];

  UserOption _optionFor(AppUser user) {
    final jobRole = user.jobRole;
    if (user.id == null || jobRole == null || jobRole.id == null) {
      return UserOption(
        user: user,
        enabled: false,
        detail: 'Sin puesto asignado',
        conflict: true,
      );
    }
    if (_slot.contains(user)) {
      return UserOption(
        user: user,
        enabled: false,
        detail: 'Ya está en esta franja.',
      );
    }
    final conflict = firstOverlappingShift(
      widget.dayShifts,
      startMin: _slot.startMin,
      endMin: _slot.endMin,
      userId: user.id,
    );
    if (conflict != null) {
      return UserOption(
        user: user,
        enabled: false,
        detail: 'Ya tiene turno ${conflict.timeLabel} · '
            '${conflict.floor.label}',
        conflict: true,
      );
    }
    final others = _otherShifts(user);
    if (others.isEmpty) {
      return UserOption(
        user: user,
        enabled: true,
        detail: '${jobRole.name} · ${jobRole.floor.label}',
      );
    }
    final summary = others.map((shift) => shift.timeLabel).join(', ');
    return UserOption(
      user: user,
      enabled: true,
      detail: '${jobRole.name} · sin solape; ese día también $summary',
    );
  }

  void _save() {
    if (_selected.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final slot = _slot;
    final status = slot.shifts.any((shift) => shift.status != ShiftStatus.draft)
        ? ShiftStatus.published
        : ShiftStatus.draft;
    final selectedUsers = [
      for (final user in widget.users)
        if (user.id != null && _selected.contains(user.id)) user,
    ];
    Navigator.pop<List<Shift>>(
      context,
      [
        for (final user in selectedUsers)
          _buildShift(user: user, slot: slot, status: status),
      ],
    );
  }

  Shift _buildShift({
    required AppUser user,
    required _Slot slot,
    required ShiftStatus status,
  }) =>
      Shift(
        date: widget.date,
        userId: user.id!,
        userName: user.fullName,
        roleId: user.jobRole!.id!,
        roleName: user.jobRole!.name,
        floor: widget.floor,
        startMin: slot.startMin,
        endMin: slot.endMin,
        breakMin: breakMinutesFor(
          startMin: slot.startMin,
          endMin: slot.endMin,
        ),
        status: status,
        note: user.jobRole!.note.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_slots.isEmpty) {
      return AlertDialog(
        title: const Text('Añadir personas'),
        content: const Text('No hay ninguna franja horaria en esta planta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }
    final options = [for (final user in widget.users) _optionFor(user)];

    return AlertDialog(
      title: Text('Añadir personas · ${widget.floor.label}'),
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
              DropdownButtonFormField<int>(
                initialValue: _slotIndex,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Franja horaria'),
                items: [
                  for (var index = 0; index < _slots.length; index++)
                    DropdownMenuItem<int>(
                      value: index,
                      child: Text(_slots[index].label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _slotIndex = value;
                    _selected.clear();
                    _showError = false;
                  });
                },
              ),
              const Divider(height: 24),
              Text('Personas', style: theme.textTheme.labelLarge),
              if (_selected.isEmpty && _showError)
                Text(
                  'Selecciona al menos una persona.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Añadir')),
      ],
    );
  }
}
