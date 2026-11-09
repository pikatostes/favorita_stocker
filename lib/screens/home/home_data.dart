import 'package:flutter/foundation.dart';

import '../../auth_controller.dart';
import '../../db.dart';
import '../../models.dart';
import '../../prediction.dart';
import '../../schedule.dart';
import '../../shifts.dart';

/// Resumen de la última lista de montaje guardada, preparado para abrir
/// `PlanScreen`: [qty] lleva solo los botellines sueltos y [fullBoxes] las
/// cajas completas, igual que el flujo de Lista → Confirmar → Plan.
class NightListSummary {
  final String date;
  final Map<int, int> qty;
  final Map<int, int> fullBoxes;
  final int totalUnits;
  final int products;

  const NightListSummary({
    required this.date,
    required this.qty,
    required this.fullBoxes,
    required this.totalUnits,
    required this.products,
  });

  /// Construye el resumen a partir del consumo guardado. Devuelve `null` si no
  /// hay ningún producto con cantidad positiva.
  static NightListSummary? fromConsumption({
    required String date,
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
      qty: qty,
      fullBoxes: fullBoxes,
      totalUnits: totalUnits,
      products: count,
    );
  }
}

/// Datos que necesita el panel de Inicio para pintarse.
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
  List<AppUser> get eligibleUsers =>
      activeUsers.where((user) => user.jobRole != null).toList(growable: false);

  bool get hasEligibleUsers => eligibleUsers.isNotEmpty;

  int get activeUsersWithoutRole =>
      activeUsers.where((user) => user.jobRole == null).length;

  int countShifts(ShiftStatus status) =>
      monthShifts.where((shift) => shift.status == status).length;

  /// Plantas que no tienen ningún opener disponible para [focusDay].
  Set<Floor> get floorsWithoutOpener {
    final result = <Floor>{};
    for (final floor in Floor.values) {
      final hasOpener = eligibleUsers.any(
        (user) =>
            user.jobRole!.floor == floor &&
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
        'Añade puestos y usuarios activos para generar el horario',
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

/// Carga en paralelo todo lo que necesita el panel de Inicio.
Future<HomeData> loadHomeData() async {
  final now = DateTime.now();
  final user = AuthController.i.user;
  final isAdmin = user?.role == UserRole.admin;

  final special = await Db.i.specialDays();
  final serviceDay = Schedule.serviceDay(now);
  final serviceOpen = Schedule.isOpen(serviceDay, special);
  final openNow = serviceOpen &&
      (now.hour >= Schedule.openHour || now.hour < Schedule.closeHour);
  final today = Schedule.day(now);
  final opensLaterToday =
      Schedule.isOpen(today, special) && now.hour < Schedule.openHour;
  final nextOpen = Schedule.nextOpen(now, special);
  final focusDay = openNow ? serviceDay : nextOpen;

  final month = DateTime(now.year, now.month);
  final monthShifts = await Db.i.shiftsForMonth(month);

  // El foco puede caer en el mes siguiente (o en el anterior si estamos de
  // madrugada el día 1), así que se consulta su mes cuando hace falta.
  final focusMonth = DateTime(focusDay.year, focusDay.month);
  final focusMonthShifts =
      focusMonth.year == month.year && focusMonth.month == month.month
          ? monthShifts
          : await Db.i.shiftsForMonth(focusMonth);
  final focusKey = Schedule.fmt(focusDay);
  final focusShifts =
      focusMonthShifts.where((shift) => shift.date == focusKey).toList();

  final users = await Db.i.users(includeInactive: isAdmin);
  final nightList =
      user?.isMaintenance == true ? await _latestNightList() : null;

  ForecastResult? forecast;
  if (isAdmin) {
    try {
      forecast = await Predictor.forecast(nextOpen);
    } catch (error) {
      // La previsión es información secundaria: si falla, el resto del Inicio
      // debe seguir siendo utilizable.
      debugPrint('No se pudo calcular la previsión de Inicio: $error');
    }
  }

  var myUpcoming = <Shift>[];
  var mySchedulePending = false;
  if (user != null && !isAdmin) {
    // Antes de las 04:00 seguimos en la noche de servicio anterior; a partir
    // de esa hora, el siguiente turno se busca desde el día natural de hoy.
    final from = now.hour < Schedule.closeHour
        ? Schedule.fmt(serviceDay)
        : Schedule.fmt(today);
    final nextMonth = DateTime(month.year, month.month + 1);
    final nextMonthShifts = await Db.i.shiftsForMonth(nextMonth);
    final mySource = <Shift>[...monthShifts, ...nextMonthShifts];
    // Si estamos de madrugada el día 1, el servicio en curso pertenece al mes
    // anterior.
    if (openNow &&
        (focusMonth.year != month.year || focusMonth.month != month.month)) {
      mySource.addAll(focusMonthShifts);
    }
    final myAll = mySource
        .where((shift) =>
            shift.userId == user.id && shift.date.compareTo(from) >= 0)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.startMin.compareTo(b.startMin);
      });
    myUpcoming = myAll
        .where((shift) => shift.status != ShiftStatus.draft)
        .toList(growable: false);
    mySchedulePending = myUpcoming.isEmpty && myAll.isNotEmpty;
  }

  return HomeData(
    now: now,
    serviceDay: serviceDay,
    focusDay: focusDay,
    nextOpen: nextOpen,
    openNow: openNow,
    opensLaterToday: opensLaterToday,
    special: special,
    users: users,
    monthShifts: monthShifts,
    focusShifts: focusShifts,
    myUpcoming: myUpcoming,
    mySchedulePending: mySchedulePending,
    forecast: forecast,
    nightList: nightList,
  );
}

/// El puesto de mantenimiento no tiene notificaciones: en Inicio ve un aviso
/// con la última lista guardada y, si existe, abre directamente el montaje.
Future<NightListSummary?> _latestNightList() async {
  final date = await Db.i.latestNightDate();
  if (date == null) return null;
  final saved = await Db.i.nightConsumption(date);
  final products = await Db.i.products();
  final byId = <int, Product>{
    for (final product in products)
      if (product.id != null) product.id!: product,
  };
  return NightListSummary.fromConsumption(
    date: date,
    saved: saved,
    productsById: byId,
  );
}
