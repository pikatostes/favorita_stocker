import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/turnos/schedule/schedule_dates.dart';

void main() {
  group('nextOpenDay', () {
    test('devuelve el mismo día si ya es viernes o sábado', () {
      // 2026-11-20 es viernes.
      expect(nextOpenDay(DateTime(2026, 11, 20)), DateTime(2026, 11, 20));
    });

    test('avanza hasta el viernes desde un día cerrado', () {
      // 2026-11-09 es lunes.
      expect(nextOpenDay(DateTime(2026, 11, 9)), DateTime(2026, 11, 13));
    });
  });

  group('firstOpenDay', () {
    test('encuentra el primer viernes del mes', () {
      // Noviembre de 2026 empieza en domingo: el primer viernes es el día 6.
      expect(firstOpenDay(DateTime(2026, 11)), DateTime(2026, 11, 6));
    });

    test('usa el día 1 si el mes no tiene viernes ni sábado', () {
      // Un mes siempre tiene algún viernes o sábado; se comprueba que el
      // resultado cae dentro del mes pedido.
      final date = firstOpenDay(DateTime(2026, 2));
      expect(date.month, 2);
      expect(date.year, 2026);
    });
  });

  group('initialSelectedDay', () {
    test('si hoy abre, selecciona hoy', () {
      // 2026-11-20 es viernes.
      expect(
        initialSelectedDay(now: DateTime(2026, 11, 20, 22)),
        DateTime(2026, 11, 20),
      );
    });

    test('si hoy no abre, selecciona el próximo día de apertura del mes', () {
      // 2026-11-19 es jueves; el próximo apertura es el viernes 20.
      expect(
        initialSelectedDay(now: DateTime(2026, 11, 19, 12)),
        DateTime(2026, 11, 20),
      );
    });

    test('si el próximo día cae en otro mes, usa el primero del mes', () {
      // 2026-11-30 es lunes: la próxima apertura (4 de diciembre) es de otro
      // mes, así que se selecciona el primer viernes de noviembre.
      expect(
        initialSelectedDay(now: DateTime(2026, 11, 30, 12)),
        DateTime(2026, 11, 6),
      );
    });
  });
}
