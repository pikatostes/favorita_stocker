import 'package:intl/intl.dart';

/// Calendario y horario del bar.
class Schedule {
  /// Días habituales de apertura.
  static const openWeekdays = {DateTime.friday, DateTime.saturday};

  static const openHour = 16; // abre a las 16:00
  static const peakHour = 21; // de 21:00 a 04:00 hay más gente y más personal
  static const closeHour = 4; // cierra a las 04:00 (ya al día siguiente)

  /// Años de histórico que se conservan.
  static const retentionYears = 2;

  static final _f = DateFormat('yyyy-MM-dd');
  static String fmt(DateTime d) => _f.format(d);
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// ¿Se abre ese día? Las excepciones mandan sobre el calendario habitual.
  static bool isOpen(DateTime d, Map<String, SpecialDay> special) {
    final s = special[fmt(d)];
    return s != null ? s.open : openWeekdays.contains(d.weekday);
  }

  /// Próximo día de apertura a partir de [from] (incluido).
  static DateTime nextOpen(DateTime from, Map<String, SpecialDay> special) {
    var d = day(from);
    for (var i = 0; i < 400; i++) {
      if (isOpen(d, special)) return d;
      d = d.add(const Duration(days: 1));
    }
    return day(from);
  }

  /// Día de servicio al que pertenece un instante. La noche empieza a las
  /// 16:00, así que cualquier hora anterior (p. ej. las 3:00) es de la noche
  /// que empezó el día anterior.
  static DateTime serviceDay(DateTime now) =>
      day(now.hour < openHour ? now.subtract(const Duration(days: 1)) : now);

  static DateTime retentionLimit([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year - retentionYears, n.month, n.day);
  }
}
