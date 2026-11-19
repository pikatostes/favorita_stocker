import '../models.dart';
import '../shifts.dart';

/// Datos de la pestaña Horario: turnos del mes, usuarios con puesto y
/// excepciones del calendario.
class ScheduleData {
  final List<Shift> shifts;
  final List<AppUser> users;
  final Map<String, SpecialDay> special;

  /// Turnos agrupados por fecha (`yyyy-MM-dd`), calculado una sola vez al
  /// cargar. Cambiar de día o de vista no vuelve a recorrer la lista.
  final Map<String, List<Shift>> byDate;

  ScheduleData({
    required this.shifts,
    required this.users,
    required this.special,
  }) : byDate = _groupByDate(shifts);

  bool get hasUsers => users.isNotEmpty;

  List<Shift> shiftsFor(String date) => byDate[date] ?? const [];

  static Map<String, List<Shift>> _groupByDate(List<Shift> shifts) {
    final result = <String, List<Shift>>{};
    for (final shift in shifts) {
      result.putIfAbsent(shift.date, () => []).add(shift);
    }
    return Map.unmodifiable({
      for (final entry in result.entries)
        entry.key: List<Shift>.unmodifiable(entry.value),
    });
  }
}
