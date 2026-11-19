import '../../../schedule.dart';
import '../../../shifts.dart';

/// Convierte una hora a un eje continuo de la noche.
///
/// La madrugada (antes de [Schedule.openHour]) pertenece al día siguiente, así
/// que se suma un día para poder comparar franjas que cruzan medianoche sin
/// que un turno de 23:00–04:00 parezca no solaparse con uno de 02:00–03:00.
int nightAxisMinute(int minute) =>
    minute < Schedule.openHour * 60 ? minute + 24 * 60 : minute;

/// ¿Se solapan dos franjas horarias?
///
/// [aEnd] y [bEnd] siguen la convención de [Shift]: si la salida es menor que
/// la entrada, la franja cruza medianoche. Dos franjas que solo se tocan (por
/// ejemplo, 17:00–20:00 y 20:00–22:00) no se consideran solapadas.
bool minutesOverlap(int aStart, int aEnd, int bStart, int bEnd) {
  final a0 = nightAxisMinute(aStart);
  final a1 = nightAxisMinute(aEnd);
  final b0 = nightAxisMinute(bStart);
  final b1 = nightAxisMinute(bEnd);
  return a0 < b1 && b0 < a1;
}

/// Primer turno de [shifts] que se solapa con [startMin]–[endMin].
///
/// [userId] limita la búsqueda a una persona concreta y [skip] permite ignorar
/// turnos que ya se han tratado aparte (por ejemplo, el propio turno de la
/// franja que se está editando).
Shift? firstOverlappingShift(
  Iterable<Shift> shifts, {
  required int startMin,
  required int endMin,
  int? userId,
  bool Function(Shift shift)? skip,
}) {
  for (final shift in shifts) {
    if (userId != null && shift.userId != userId) continue;
    if (skip != null && skip(shift)) continue;
    if (minutesOverlap(startMin, endMin, shift.startMin, shift.endMin)) {
      return shift;
    }
  }
  return null;
}
