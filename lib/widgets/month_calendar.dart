import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Apariencia de un día dentro de [MonthCalendar].
///
/// Solo describe el estado del día (relleno, color del número y borde). El
/// calendario se encarga de superponer el borde de selección y el énfasis de
/// "hoy", para que todas las pantallas se vean igual.
class CalendarDayStyle {
  final Color? fill;
  final Color? textColor;
  final Border? border;

  const CalendarDayStyle({this.fill, this.textColor, this.border});
}

/// Calendario mensual compartido por las pantallas de Calendario y Turnos.
///
/// La cabecera (mes anterior/siguiente) y la rejilla son comunes; cada pantalla
/// aporta el significado de sus días con [styleFor] y, si lo necesita, un
/// indicador extra debajo del número con [footerFor].
class MonthCalendar extends StatelessWidget {
  /// Cualquier fecha del mes que se quiere mostrar.
  final DateTime month;

  /// Día resaltado con el borde de selección.
  final DateTime selected;

  final ValueChanged<DateTime> onSelect;

  /// Se llama con el primer día del mes anterior o siguiente.
  final ValueChanged<DateTime> onMonthChanged;

  /// Estado visual de [day]. Por defecto, un día normal.
  final CalendarDayStyle Function(DateTime day)? styleFor;

  /// Contenido opcional bajo el número (contador de turnos, marca de
  /// excepción...). Si es `null`, la celda solo muestra el número.
  final Widget? Function(DateTime day)? footerFor;

  /// Acción adicional al final de la cabecera (por ejemplo, el botón «Hoy»).
  final Widget? headerTrailing;

  /// Contenido a ancho completo justo debajo de la cabecera del mes, antes de
  /// los días de la semana. Sirve para acciones que dependen del mes mostrado.
  final Widget? headerActions;

  /// Altura de cada celda. Debe dejar sitio al número (38 px) y al [footerFor].
  final double cellHeight;
  final String locale;

  const MonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.onMonthChanged,
    this.styleFor,
    this.footerFor,
    this.headerTrailing,
    this.headerActions,
    this.cellHeight = 44,
    this.locale = 'es',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    // Se completa la última fila para que todas tengan siete celdas.
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final monthLabel = DateFormat('MMMM yyyy', locale).format(first);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _capitalize(monthLabel),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
            if (headerTrailing != null) headerTrailing!,
          ],
        ),
        if (headerActions != null) ...[
          const SizedBox(height: 4),
          headerActions!,
        ],
        Row(
          children: [
            for (final label in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length; row += 7)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _dayCell(context, cells[row + col])),
            ],
          ),
      ],
    );
  }

  void _changeMonth(int delta) {
    onMonthChanged(DateTime(month.year, month.month + delta));
  }

  Widget _dayCell(BuildContext context, DateTime? day) {
    if (day == null) return SizedBox(height: cellHeight);

    final cs = Theme.of(context).colorScheme;
    final style = styleFor?.call(day) ?? const CalendarDayStyle();
    final isToday = _sameDay(day, DateTime.now());
    final isSelected = _sameDay(day, selected);
    final footer = footerFor?.call(day);
    final border =
        isSelected ? Border.all(color: cs.onSurface, width: 2.5) : style.border;

    return InkWell(
      onTap: () => onSelect(day),
      child: SizedBox(
        height: cellHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.fill,
                border: border,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: style.textColor ?? cs.onSurface,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.normal,
                  decoration: isToday ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
