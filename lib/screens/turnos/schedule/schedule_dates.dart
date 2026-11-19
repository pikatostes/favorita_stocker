import '../../../schedule.dart';

/// Normaliza una fecha a medianoche.
DateTime scheduleDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Primer viernes o sábado a partir de [from] (incluido).
DateTime nextOpenDay(DateTime from) {
  var date = scheduleDay(from);
  for (var i = 0; i < 14; i++) {
    if (Schedule.openWeekdays.contains(date.weekday)) return date;
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return scheduleDay(from);
}

/// Primer viernes o sábado del mes.
DateTime firstOpenDay(DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= days; day++) {
    final date = DateTime(month.year, month.month, day);
    if (Schedule.openWeekdays.contains(date.weekday)) return date;
  }
  return DateTime(month.year, month.month, 1);
}

/// Día seleccionado al abrir la pestaña: hoy si el bar abre; si no, el próximo
/// viernes/sábado del mes o el primero del mes si el próximo cae en otro mes.
///
/// [now] se puede inyectar en pruebas.
DateTime initialSelectedDay({DateTime? now}) {
  final today = scheduleDay(now ?? DateTime.now());
  if (Schedule.openWeekdays.contains(today.weekday)) return today;
  final next = nextOpenDay(today);
  final sameMonth = next.year == today.year && next.month == today.month;
  return sameMonth ? next : firstOpenDay(today);
}
