import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/models.dart';
import 'package:stock_bar/schedule.dart';

void main() {
  group('Schedule', () {
    test('formatea la fecha como yyyy-MM-dd', () {
      expect(Schedule.fmt(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('el día de servicio empieza a las 16:00', () {
      // Las 3:00 de la madrugada pertenecen a la noche anterior.
      expect(
        Schedule.serviceDay(DateTime(2026, 1, 2, 3, 0)),
        DateTime(2026, 1, 1),
      );
      // A partir de las 16:00 es el mismo día.
      expect(
        Schedule.serviceDay(DateTime(2026, 1, 2, 20, 0)),
        DateTime(2026, 1, 2),
      );
    });

    test('abre viernes y sábado por defecto', () {
      const special = <String, SpecialDay>{};
      final friday = DateTime(2026, 1, 2); // viernes
      final monday = DateTime(2026, 1, 5); // lunes

      expect(friday.weekday, DateTime.friday);
      expect(Schedule.isOpen(friday, special), isTrue);
      expect(Schedule.isOpen(monday, special), isFalse);
    });

    test('las excepciones mandan sobre el calendario habitual', () {
      final monday = DateTime(2026, 1, 5);
      final friday = DateTime(2026, 1, 2);

      final opensMonday = {
        '2026-01-05': SpecialDay('2026-01-05', open: true),
      };
      final closesFriday = {
        '2026-01-02': SpecialDay('2026-01-02', open: false),
      };

      expect(Schedule.isOpen(monday, opensMonday), isTrue);
      expect(Schedule.isOpen(friday, closesFriday), isFalse);
    });

    test('nextOpen encuentra el próximo día de apertura', () {
      final monday = DateTime(2026, 1, 5);

      expect(Schedule.nextOpen(monday, const {}), DateTime(2026, 1, 9));
    });

    test('retentionLimit resta los años de histórico', () {
      expect(
        Schedule.retentionLimit(DateTime(2026, 3, 10)),
        DateTime(2024, 3, 10),
      );
    });
  });
}
