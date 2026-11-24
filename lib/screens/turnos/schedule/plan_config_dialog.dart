import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../formats.dart';
import '../../../models.dart';
import '../../../shifts.dart';

/// Última configuración usada en esta sesión.
///
/// Se mantiene en memoria: al reiniciar la app se vuelve a
/// [ShiftPlanConfig] por defecto.
final ValueNotifier<ShiftPlanConfig> shiftPlanConfigNotifier =
    ValueNotifier(const ShiftPlanConfig());

/// Abre la card de configuración del horario del mes.
///
/// Devuelve la configuración elegida cuando se pulsa «Generar horario», o
/// `null` si se cancela. [existingShifts] solo se usa para avisar de que se
/// van a borrar los turnos actuales del mes.
Future<ShiftPlanConfig?> showShiftPlanDialog(
  BuildContext context, {
  required DateTime month,
  required List<AppUser> users,
  required Map<String, SpecialDay> specialDays,
  int existingShifts = 0,
}) =>
    showDialog<ShiftPlanConfig>(
      context: context,
      builder: (_) => _ShiftPlanDialog(
        month: month,
        users: users,
        specialDays: specialDays,
        existingShifts: existingShifts,
      ),
    );

class _ShiftPlanDialog extends StatefulWidget {
  final DateTime month;
  final List<AppUser> users;
  final Map<String, SpecialDay> specialDays;
  final int existingShifts;

  const _ShiftPlanDialog({
    required this.month,
    required this.users,
    required this.specialDays,
    required this.existingShifts,
  });

  @override
  State<_ShiftPlanDialog> createState() => _ShiftPlanDialogState();
}

class _ShiftPlanDialogState extends State<_ShiftPlanDialog> {
  late ShiftPlanConfig _config = shiftPlanConfigNotifier.value;

  void _update(ShiftPlanConfig config) => setState(() => _config = config);

  Future<void> _pickTime({
    required int current,
    required ShiftPlanConfig Function(int minutes) apply,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (current ~/ 60) % 24,
        minute: current % 60,
      ),
    );
    if (picked == null || !mounted) return;
    _update(apply(picked.hour * 60 + picked.minute));
  }

  void _toggleWeekday(int day, bool selected) {
    final days = {..._config.weekdays};
    if (selected) {
      days.add(day);
    } else {
      days.remove(day);
    }
    _update(_config.copyWith(weekdays: days));
  }

  void _setMinimum(Floor floor, FloorMinimums Function(FloorMinimums) change) {
    final current = _config.minimumsFor(floor);
    _update(_config.withMinimum(floor, change(current)));
  }

  void _confirm() {
    shiftPlanConfigNotifier.value = _config;
    Navigator.pop(context, _config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _config.validationError;
    final preview = error == null
        ? ShiftGenerator.generateMonth(
            month: widget.month,
            users: widget.users,
            specialDays: widget.specialDays,
            config: _config,
          )
        : const <Shift>[];
    final people = preview.map((shift) => shift.userId).toSet().length;

    final String summary;
    if (error != null) {
      summary = error;
    } else if (preview.isEmpty) {
      summary = 'No se generará ningún turno con esta configuración.';
    } else {
      summary = 'Se generarán ${preview.length} turnos para $people personas.';
    }

    return AlertDialog(
      title: Text('Horario de ${formatMonthLabel(widget.month)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Días'),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (var day = DateTime.monday;
                      day <= DateTime.sunday;
                      day++)
                    FilterChip(
                      key: ValueKey('weekday-$day'),
                      label: Text(weekdayShort(day)),
                      selected: _config.weekdays.contains(day),
                      onSelected: (selected) => _toggleWeekday(day, selected),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('Tramos'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _TimeButton(
                    label: 'Apertura',
                    minutes: _config.openingStart,
                    onPressed: () => _pickTime(
                      current: _config.openingStart,
                      apply: (minutes) =>
                          _config.copyWith(openingStart: minutes),
                    ),
                  ),
                  _TimeButton(
                    label: 'Cambio',
                    minutes: _config.openingEnd,
                    onPressed: () => _pickTime(
                      current: _config.openingEnd,
                      apply: (minutes) =>
                          _config.copyWith(openingEnd: minutes),
                    ),
                  ),
                  _TimeButton(
                    label: 'Cierre',
                    minutes: _config.closingEnd,
                    onPressed: () => _pickTime(
                      current: _config.closingEnd,
                      apply: (minutes) =>
                          _config.copyWith(closingEnd: minutes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('Personas mínimas'),
              const Row(
                children: [
                  Expanded(child: SizedBox()),
                  _MinHeader('Apertura'),
                  SizedBox(width: AppSpacing.sm),
                  _MinHeader('Segundo'),
                ],
              ),
              for (final floor in Floor.values)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(floor.label)),
                      _MinField(
                        key: ValueKey('min-${floor.db}-open'),
                        label: 'Apertura',
                        value: _config.minimumsFor(floor).open,
                        onChanged: (value) => _setMinimum(
                          floor,
                          (mins) => mins.copyWith(open: value),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _MinField(
                        key: ValueKey('min-${floor.db}-peak'),
                        label: 'Segundo',
                        value: _config.minimumsFor(floor).peak,
                        onChanged: (value) => _setMinimum(
                          floor,
                          (mins) => mins.copyWith(peak: value),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir turnos completos'),
                subtitle: Text(
                  'Usa ${formatMinutes(_config.openingStart)}–'
                  '${formatMinutes(_config.closingEnd)} cuando no hay '
                  'personas suficientes para cubrir los dos tramos.',
                ),
                value: _config.allowFullShifts,
                onChanged: (value) =>
                    _update(_config.copyWith(allowFullShifts: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Terraza a las 21:00 los viernes'),
                subtitle: Text(
                  'La terraza empieza en el segundo tramo '
                  '(${formatMinutes(_config.openingEnd)}) los viernes.',
                ),
                value: _config.terraceFridayLate,
                onChanged: (value) =>
                    _update(_config.copyWith(terraceFridayLate: value)),
              ),
              if (widget.existingShifts > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    'Se borrarán los ${widget.existingShifts} turnos actuales '
                    'de este mes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: error != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
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
        FilledButton(
          onPressed: error == null ? _confirm : null,
          child: const Text('Generar horario'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _TimeButton extends StatelessWidget {
  final String label;
  final int minutes;
  final VoidCallback onPressed;

  const _TimeButton({
    required this.label,
    required this.minutes,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.schedule, size: 18),
        label: Text('$label ${formatMinutes(minutes)}'),
      );
}

class _MinHeader extends StatelessWidget {
  final String text;

  const _MinHeader(this.text);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _MinField.width,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

class _MinField extends StatelessWidget {
  static const double width = 104;

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _MinField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: DropdownButtonFormField<int>(
          initialValue: value,
          isDense: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            for (var count = 0; count <= 6; count++)
              DropdownMenuItem(value: count, child: Text('$count')),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      );
}
