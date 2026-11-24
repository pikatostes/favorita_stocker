import '../models.dart';
import '../schedule.dart';
import '../shifts.dart';

/// Resumen de la última lista de montaje guardada, preparado para abrir
/// `PlanScreen`: [qty] lleva solo los botellines sueltos y [fullBoxes] las
/// cajas completas, igual que el flujo de Lista → Confirmar → Plan.
class NightListSummary {
  final String date;
  final Floor floor;
  final Map<int, int> qty;
  final Map<int, int> fullBoxes;
  final int totalUnits;
  final int products;

  const NightListSummary({
    required this.date,
    required this.floor,
    required this.qty,
    required this.fullBoxes,
    required this.totalUnits,
    required this.products,
  });

  /// Construye el resumen a partir del consumo guardado. Devuelve `null` si no
  /// hay ningún producto con cantidad positiva.
  static NightListSummary? fromConsumption({
    required String date,
    required Floor floor,
    required Map<int, int> saved,
    required Map<int, Product> productsById,
  }) {
    final qty = <int, int>{}; // sueltos
    final fullBoxes = <int, int>{}; // cajas completas
    var totalUnits = 0;
    var count = 0;
    for (final entry in saved.entries) {
      final product = productsById[entry.key];
      if (product == null || entry.value <= 0) continue;
      final size = product.unitsPerBox < 1 ? 1 : product.unitsPerBox;
      final boxes = entry.value ~/ size;
      final loose = entry.value % size;
      if (boxes > 0) fullBoxes[entry.key] = boxes;
      if (loose > 0) qty[entry.key] = loose;
      totalUnits += entry.value;
      count++;
    }
    if (count == 0) return null;
    return NightListSummary(
      date: date,
      floor: floor,
      qty: qty,
      fullBoxes: fullBoxes,
      totalUnits: totalUnits,
      products: count,
    );
  }
}

/// Contadores de turnos del mes por estado.
typedef ShiftCounts = ({int drafts, int published, int confirmed});

/// Datos que necesita el panel de Inicio para pintarse.
///
/// Es un modelo de lectura: se construye una vez por carga y no depende de
/// widgets ni de la base de datos, así que se puede probar por separado.
class HomeData {
  final DateTime now;
  final DateTime serviceDay;
  final DateTime focusDay;
  final DateTime nextOpen;
  final bool openNow;
  final bool opensLaterToday;
  final Map<String, SpecialDay> special;
  final List<AppUser> users;
  final List<Shift> monthShifts;
  final List<Shift> focusShifts;
  final List<Shift> myUpcoming;
  final bool mySchedulePending;
  final ForecastResult? forecast;
  final NightListSummary? nightList;

  const HomeData({
    required this.now,
    required this.serviceDay,
    required this.focusDay,
    required this.nextOpen,
    required this.openNow,
    required this.opensLaterToday,
    required this.special,
    required this.users,
    required this.monthShifts,
    required this.focusShifts,
    required this.myUpcoming,
    required this.mySchedulePending,
    required this.forecast,
    required this.nightList,
  });

  DateTime get month => DateTime(now.year, now.month);

  bool get focusIsService => Schedule.fmt(focusDay) == Schedule.fmt(serviceDay);

  bool get focusIsTonight =>
      focusIsService ||
      Schedule.fmt(focusDay) == Schedule.fmt(Schedule.day(now));

  List<AppUser> get activeUsers =>
      users.where((user) => user.active).toList(growable: false);

  /// Usuarios activos que ya tienen un puesto asignado y pueden entrar en el
  /// generador de horarios.
  List<AppUser> get eligibleUsers => activeUsers
      .where((user) => user.jobPosition != null)
      .toList(growable: false);

  bool get hasEligibleUsers => eligibleUsers.isNotEmpty;

  int get activeUsersWithoutRole =>
      activeUsers.where((user) => user.jobPosition == null).length;

  /// Nombre nuevo del mismo contador.
  int get activeUsersWithoutPosition => activeUsersWithoutRole;

  /// Contadores por estado en una sola pasada; las tarjetas los reutilizan en
  /// lugar de recorrer la lista varias veces.
  ShiftCounts get shiftCounts {
    var drafts = 0;
    var published = 0;
    var confirmed = 0;
    for (final shift in monthShifts) {
      switch (shift.status) {
        case ShiftStatus.draft:
          drafts++;
        case ShiftStatus.published:
          published++;
        case ShiftStatus.confirmed:
          confirmed++;
      }
    }
    return (drafts: drafts, published: published, confirmed: confirmed);
  }

  /// Plantas que no tienen ningún opener disponible para [focusDay].
  Set<Floor> get floorsWithoutOpener {
    final result = <Floor>{};
    for (final floor in Floor.values) {
      final hasOpener = eligibleUsers.any(
        (user) =>
            user.effectiveFloor == floor &&
            user.opener &&
            (user.workingDays.isEmpty ||
                user.workingDays.contains(focusDay.weekday)),
      );
      if (!hasOpener) result.add(floor);
    }
    return result;
  }

  /// Turnos de la noche de foco que puede ver un empleado (sin borradores).
  List<Shift> get publishedFocusShifts => focusShifts
      .where((shift) => shift.status != ShiftStatus.draft)
      .toList(growable: false);

  /// Días de apertura del mes actual que todavía no tienen turnos generados.
  int get openDaysWithoutShifts {
    final dates = monthShifts.map((shift) => shift.date).toSet();
    final today = Schedule.day(now);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    var count = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      // Los días pasados ya no se pueden corregir; interesan los próximos.
      if (date.isBefore(today)) continue;
      if (Schedule.isOpen(date, special) &&
          !dates.contains(Schedule.fmt(date))) {
        count++;
      }
    }
    return count;
  }

  /// Avisos de planificación del mes, en el orden en que se muestran.
  List<String> get planningWarnings {
    final pendingDays = openDaysWithoutShifts;
    return [
      if (!hasEligibleUsers)
        'Añade usuarios activos con puesto para generar el horario',
      if (pendingDays > 0)
        pendingDays == 1
            ? '1 día de apertura sin turnos'
            : '$pendingDays días de apertura sin turnos',
      if (activeUsersWithoutRole > 0)
        activeUsersWithoutRole == 1
            ? '1 usuario activo sin puesto'
            : '$activeUsersWithoutRole usuarios activos sin puesto',
    ];
  }
}
