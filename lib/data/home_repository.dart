import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth_controller.dart';
import '../db.dart';
import '../models.dart';
import '../prediction.dart';
import '../schedule.dart';
import '../shifts.dart';
import 'home_data.dart';

/// Acceso a los datos del panel de Inicio.
///
/// La pantalla no consulta [Db] directamente: pide un [HomeData] ya montado.
/// Así se puede cambiar el origen de datos o precargar el panel sin tocar los
/// widgets.
class HomeRepository {
  HomeRepository._();
  static final HomeRepository i = HomeRepository._();

  /// Carga en paralelo todo lo que necesita el panel.
  ///
  /// [user] y [now] se pueden inyectar en pruebas; por defecto se usan el
  /// usuario autenticado y la hora actual. Las consultas independientes se
  /// lanzan antes de esperar la primera, de modo que el panel tarda lo que la
  /// consulta más lenta y no la suma de todas.
  Future<HomeData> load({AppUser? user, DateTime? now}) async {
    try {
      return await _load(user: user, now: now);
    } on ParallelWaitError catch (error) {
      // `(future, …).wait` envuelve los fallos: se relanza la causa real para
      // que la UI muestre el error de la consulta que falló.
      throw _firstParallelError(error) ?? error;
    }
  }

  Future<HomeData> _load({AppUser? user, DateTime? now}) async {
    final currentUser = user ?? AuthController.i.user;
    final currentNow = now ?? DateTime.now();
    final isAdmin = currentUser?.role == UserRole.admin;
    final today = Schedule.day(currentNow);
    final month = DateTime(currentNow.year, currentNow.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final needsMyShifts = currentUser != null && !isAdmin;

    // Consultas independientes: se lanzan ya y se esperan más abajo.
    final specialFuture = Db.i.specialDays();
    final monthShiftsFuture = Db.i.shiftsForMonth(month);
    final usersFuture = Db.i.users(includeInactive: isAdmin);
    final nextMonthShiftsFuture = needsMyShifts
        ? Db.i.shiftsForMonth(nextMonth)
        : Future<List<Shift>>.value(const []);
    final nightListFuture = currentUser?.isMaintenance == true
        ? _latestNightList()
        : Future<NightListSummary?>.value();

    final special = await specialFuture;
    final serviceDay = Schedule.serviceDay(currentNow);
    final serviceOpen = Schedule.isOpen(serviceDay, special);
    final openNow = serviceOpen &&
        (currentNow.hour >= Schedule.openHour ||
            currentNow.hour < Schedule.closeHour);
    final opensLaterToday =
        Schedule.isOpen(today, special) && currentNow.hour < Schedule.openHour;
    final nextOpen = Schedule.nextOpen(currentNow, special);
    final focusDay = openNow ? serviceDay : nextOpen;

    // El foco puede caer en otro mes (o en el anterior si estamos de
    // madrugada el día 1), así que se consulta su mes cuando hace falta.
    final focusMonth = DateTime(focusDay.year, focusDay.month);
    final focusInMonth =
        focusMonth.year == month.year && focusMonth.month == month.month;
    final focusMonthShiftsFuture =
        focusInMonth ? monthShiftsFuture : Db.i.shiftsForMonth(focusMonth);
    final forecastFuture =
        isAdmin ? _forecastOrNull(nextOpen) : Future<ForecastResult?>.value();

    final (
      monthShifts,
      focusMonthShifts,
      users,
      nextMonthShifts,
      nightList,
      forecast,
    ) = await (
      monthShiftsFuture,
      focusMonthShiftsFuture,
      usersFuture,
      nextMonthShiftsFuture,
      nightListFuture,
      forecastFuture,
    ).wait;

    final focusKey = Schedule.fmt(focusDay);
    final focusShifts =
        focusMonthShifts.where((shift) => shift.date == focusKey).toList();

    var myUpcoming = <Shift>[];
    var mySchedulePending = false;
    if (needsMyShifts) {
      // Antes de las 04:00 seguimos en la noche de servicio anterior; a partir
      // de esa hora, el siguiente turno se busca desde el día natural de hoy.
      final from = currentNow.hour < Schedule.closeHour
          ? Schedule.fmt(serviceDay)
          : Schedule.fmt(today);
      final mySource = <Shift>[
        ...monthShifts,
        ...nextMonthShifts,
        // Si estamos de madrugada el día 1, el servicio en curso pertenece al
        // mes anterior.
        if (openNow && !focusInMonth) ...focusMonthShifts,
      ];
      final myAll = mySource
          .where((shift) =>
              shift.userId == currentUser.id && shift.date.compareTo(from) >= 0)
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
      now: currentNow,
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

  /// La previsión es información secundaria: si falla, el resto del Inicio
  /// debe seguir siendo utilizable.
  Future<ForecastResult?> _forecastOrNull(DateTime nextOpen) async {
    try {
      return await Predictor.forecast(nextOpen);
    } catch (error) {
      debugPrint('No se pudo calcular la previsión de Inicio: $error');
      return null;
    }
  }

  /// El puesto de mantenimiento no tiene notificaciones: en Inicio ve un aviso
  /// con la última lista guardada y, si existe, abre directamente el montaje.
  Future<NightListSummary?> _latestNightList() async {
    final latest = await Db.i.latestNight();
    if (latest == null) return null;
    final saved = await Db.i.nightConsumption(latest.date, latest.floor);
    final products = await Db.i.products();
    final byId = <int, Product>{
      for (final product in products)
        if (product.id != null) product.id!: product,
    };
    return NightListSummary.fromConsumption(
      date: latest.date,
      floor: latest.floor,
      saved: saved,
      productsById: byId,
    );
  }
}

/// Primer error real de un `(future1, …, future6).wait`.
///
/// `ParallelWaitError` guarda los errores en un record; se devuelve el primero
/// no nulo para no mostrar el envoltorio en la pantalla de error.
Object? _firstParallelError(ParallelWaitError<dynamic, dynamic> error) {
  final errors = error.errors;
  if (errors is! (
    AsyncError?,
    AsyncError?,
    AsyncError?,
    AsyncError?,
    AsyncError?,
    AsyncError?,
  )) {
    return null;
  }
  return errors.$1?.error ??
      errors.$2?.error ??
      errors.$3?.error ??
      errors.$4?.error ??
      errors.$5?.error ??
      errors.$6?.error;
}
