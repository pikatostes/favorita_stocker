import 'dart:async';

import '../db.dart';
import 'schedule_data.dart';

/// Acceso a los datos de la pestaña Horario.
///
/// Las consultas del mes, los usuarios y las excepciones se lanzan en paralelo
/// y se empaquetan en un [ScheduleData] ya agrupado por fecha.
class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository i = ScheduleRepository._();

  Future<ScheduleData> loadMonth(DateTime month) async {
    try {
      return await _loadMonth(month);
    } on ParallelWaitError catch (error) {
      // `(future, …).wait` envuelve los fallos: se relanza la causa real para
      // que la UI muestre el error de la consulta que falló.
      throw _firstParallelError(error) ?? error;
    }
  }

  Future<ScheduleData> _loadMonth(DateTime month) async {
    final shiftsFuture = Db.i.shiftsForMonth(month);
    final usersFuture = Db.i.users();
    final specialFuture = Db.i.specialDays();

    final (shifts, users, special) =
        await (shiftsFuture, usersFuture, specialFuture).wait;

    return ScheduleData(
      shifts: shifts,
      // El horario solo necesita usuarios que puedan tener turno.
      users:
          users.where((user) => user.jobRole != null).toList(growable: false),
      special: special,
    );
  }
}

/// Primer error real de un `(future1, future2, future3).wait`.
Object? _firstParallelError(ParallelWaitError<dynamic, dynamic> error) {
  final errors = error.errors;
  if (errors is! (AsyncError?, AsyncError?, AsyncError?)) return null;
  return errors.$1?.error ?? errors.$2?.error ?? errors.$3?.error;
}
