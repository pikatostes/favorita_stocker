import 'db.dart';
import 'models.dart';
import 'schedule.dart';

/// Previsión en dos pasos:
///
/// 1. BASE: media ponderada de las últimas 8 noches comparables (mismo día de
///    la semana si es viernes/sábado; cualquiera si es una apertura
///    excepcional). Las más recientes pesan más.
/// 2. TEMPORADA: se multiplica por un factor que compara, en años anteriores,
///    la época del día a prever con la época de las noches usadas como base.
///    Ej.: si el año pasado en Navidad se gastó el doble que en octubre, la
///    previsión de Navidad será ~2x la base de octubre. Usa hasta 2 años.
///
/// Por último se añade un margen de seguridad.
///
/// Ampliaciones futuras: partidos/eventos, meteorología, stock sobrante...
class Predictor {
  static const int maxNights = 8;
  static const double decay = 0.85;
  static const double safetyMargin = 0.10;
  static const int seasonWindowDays = 21; // ±3 semanas alrededor de la fecha
  static const int minNightsInWindow = 2;
  static const double minRatio = 0.5, maxRatio = 2.0;

  static Future<ForecastResult> forecast(DateTime targetIn) async {
    final target = Schedule.day(targetIn);
    final raw = await Db.i.nights();
    final history = {for (final e in raw.entries) DateTime.parse(e.key): e.value};
    final products = await Db.i.products();

    // 1) Noches base
    final usualDay = Schedule.openWeekdays.contains(target.weekday);
    List<DateTime> recent(bool sameWeekday) => (history.keys
            .where((d) =>
                d.isBefore(target) && (!sameWeekday || d.weekday == target.weekday))
            .toList()
          ..sort((a, b) => b.compareTo(a)))
        .take(maxNights)
        .toList();
    var base = recent(usualDay);
    if (base.isEmpty) base = recent(false);

    if (base.isEmpty) return ForecastResult([], 0, 0);

    // Fecha "media" de las noches base: referencia para comparar temporadas.
    final refMillis =
        base.map((d) => d.millisecondsSinceEpoch).reduce((a, b) => a + b) ~/
            base.length;
    final refCenter = Schedule.day(DateTime.fromMillisecondsSinceEpoch(refMillis));

    // 2) Años con datos suficientes en ambas épocas
    var seasonalYears = 0;
    for (var y = 1; y <= Schedule.retentionYears; y++) {
      if (_window(history, target, y).length >= minNightsInWindow &&
          _window(history, refCenter, y).length >= minNightsInWindow) {
        seasonalYears++;
      }
    }

    final items = <Forecast>[];
    for (final p in products) {
      double sum = 0, weights = 0, w = 1;
      for (final d in base) {
        sum += w * (history[d]![p.id] ?? 0);
        weights += w;
        w *= decay;
      }
      final baseAvg = sum / weights;
      final ratio = _seasonRatio(history, p.id!, target, refCenter);
      final units = (baseAvg * ratio * (1 + safetyMargin)).ceil();
      if (units > 0) items.add(Forecast(p, units));
    }
    items.sort((a, b) => b.units.compareTo(a.units));
    return ForecastResult(items, base.length, seasonalYears);
  }

  /// Noches dentro de ±[seasonWindowDays] de [center] desplazado [yearsBack] años.
  static List<Map<int, int>> _window(
      Map<DateTime, Map<int, int>> h, DateTime center, int yearsBack) {
    final c = DateTime(center.year - yearsBack, center.month, center.day);
    return h.entries
        .where((e) => e.key.difference(c).inDays.abs() <= seasonWindowDays)
        .map((e) => e.value)
        .toList();
  }

  static double? _avg(List<Map<int, int>> nights, int pid) {
    if (nights.length < minNightsInWindow) return null;
    return nights.fold<int>(0, (s, n) => s + (n[pid] ?? 0)) / nights.length;
  }

  /// Media de los cocientes (época objetivo / época base) de años anteriores.
  static double _seasonRatio(Map<DateTime, Map<int, int>> h, int pid,
      DateTime target, DateTime refCenter) {
    final ratios = <double>[];
    for (var y = 1; y <= Schedule.retentionYears; y++) {
      final t = _avg(_window(h, target, y), pid);
      final r = _avg(_window(h, refCenter, y), pid);
      if (t != null && r != null && r > 0) ratios.add(t / r);
    }
    if (ratios.isEmpty) return 1.0;
    final mean = ratios.reduce((a, b) => a + b) / ratios.length;
    return mean.clamp(minRatio, maxRatio).toDouble();
  }
}
