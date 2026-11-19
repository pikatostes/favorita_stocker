import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../schedule.dart';
import '../../../shifts.dart';
import '../../../widgets/user_avatar.dart';

/// Línea temporal de los turnos de una planta.
///
/// Cada fila agrupa a las personas que comparten el mismo horario. La barra
/// empieza en la hora de entrada y termina en la de salida (ambas rotuladas) y
/// los avatares van dentro. No se dibuja el eje con todas las horas ni hay
/// desplazamiento horizontal: si los avatares no caben en la barra, se reparten
/// en varias líneas y la fila crece en vertical.
class ShiftTimeline extends StatelessWidget {
  final List<Shift> shifts;
  final Map<int, String?> avatars;
  final ValueChanged<Shift> onEdit;
  final ValueChanged<Shift> onDelete;

  const ShiftTimeline({
    super.key,
    required this.shifts,
    this.avatars = const {},
    required this.onEdit,
    required this.onDelete,
  });

  /// Escala de la noche: de las 16:00 a las 04:00 del día siguiente.
  static const int _axisStart = Schedule.openHour * 60;
  static const int _axisEnd = 28 * 60;
  static const int _totalMinutes = _axisEnd - _axisStart;

  static const double _avatarSize = 30;
  static const double _avatarGap = 4;
  static const double _barMinHeight = 36;
  static const double _barPadding = 4;
  static const double _labelHeight = 16;
  static const double _labelGap = 2;
  static const double _rowGap = 10;

  /// Minutos del eje: lo anterior a las 16:00 pertenece a la madrugada.
  int _axisMinute(int minutes) =>
      minutes < _axisStart ? minutes + 24 * 60 : minutes;

  @override
  Widget build(BuildContext context) {
    final groups = <(int, int), List<Shift>>{};
    for (final shift in shifts) {
      groups.putIfAbsent((shift.startMin, shift.endMin), () => []).add(shift);
    }
    final rows = groups.entries.toList()
      ..sort((a, b) {
        final byStart = _axisMinute(a.key.$1) - _axisMinute(b.key.$1);
        return byStart != 0 ? byStart : a.key.$2 - b.key.$2;
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        double xOf(int minutes) {
          final m = math.min(
            _axisEnd,
            math.max(_axisStart, _axisMinute(minutes)),
          );
          return (m - _axisStart) / _totalMinutes * width;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              _timelineRow(
                context,
                row.key,
                row.value,
                width: width,
                xOf: xOf,
              ),
          ],
        );
      },
    );
  }

  Widget _timelineRow(
    BuildContext context,
    (int, int) range,
    List<Shift> rowShifts, {
    required double width,
    required double Function(int) xOf,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final start = range.$1;
    final end = range.$2;
    final sorted = [...rowShifts]..sort(
        (a, b) => a.userName.toLowerCase().compareTo(
              b.userName.toLowerCase(),
            ),
      );

    // La barra necesita un mínimo para que quepa al menos un avatar.
    const minBarWidth = _avatarSize + _barPadding * 2;
    var barLeft = xOf(start);
    var barRight = xOf(end);
    if (barRight - barLeft < minBarWidth) {
      barRight = barLeft + minBarWidth;
      if (barRight > width) {
        barRight = width;
        barLeft = math.max(0, width - minBarWidth);
      }
    }
    final barWidth = barRight - barLeft;

    // Si los avatares no caben a lo ancho, se reparten en varias líneas y la
    // fila crece en vertical (nunca se desplaza horizontalmente).
    final innerWidth = barWidth - _barPadding * 2;
    final perLine = math.max(
      1,
      ((innerWidth + _avatarGap) / (_avatarSize + _avatarGap)).floor(),
    );
    final lines = (sorted.length / perLine).ceil();
    final avatarsHeight = lines * _avatarSize + (lines - 1) * _avatarGap;
    final barHeight = math.max(
      _barMinHeight,
      avatarsHeight + _barPadding * 2,
    );
    final rowHeight = _labelHeight + _labelGap + barHeight + _rowGap;

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final separateLabels = barWidth >= 96;

    return SizedBox(
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (separateLabels) ...[
            Positioned(
              left: barLeft,
              top: 0,
              child: Text(formatMinutes(start), style: labelStyle),
            ),
            Positioned(
              right: width - barRight,
              top: 0,
              child: Text(formatMinutes(end), style: labelStyle),
            ),
          ] else
            Positioned(
              left: barLeft,
              width: barWidth,
              top: 0,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatMinutes(start)}–${formatMinutes(end)}',
                  style: labelStyle,
                ),
              ),
            ),
          Positioned(
            left: barLeft,
            top: _labelHeight + _labelGap,
            width: barWidth,
            height: barHeight,
            child: Container(
              padding: const EdgeInsets.all(_barPadding),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: _avatarGap,
                  runSpacing: _avatarGap,
                  children: [
                    for (final shift in sorted)
                      _TimelineAvatar(
                        shift: shift,
                        avatarPath: avatars[shift.userId],
                        onTap: () => onEdit(shift),
                        onLongPress: () => onDelete(shift),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar con la inicial y un punto de color según el estado del turno.
/// Tocar edita; mantener pulsado borra (con confirmación).
class _TimelineAvatar extends StatelessWidget {
  final Shift shift;
  final String? avatarPath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineAvatar({
    required this.shift,
    this.avatarPath,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = shift.userName.trim();
    final statusColor = switch (shift.status) {
      ShiftStatus.draft => cs.outline,
      ShiftStatus.published => cs.primary,
      ShiftStatus.confirmed => cs.tertiary,
    };

    return Semantics(
      button: true,
      label: '${name.isEmpty ? 'Sin nombre' : name}, '
          '${shift.timeLabel}, ${shift.status.label}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: ShiftTimeline._avatarSize,
          height: ShiftTimeline._avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(
                path: avatarPath,
                name: name,
                radius: ShiftTimeline._avatarSize / 2,
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
