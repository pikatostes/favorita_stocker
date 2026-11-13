import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_bar/formats.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('la fecha corta se separa en día de la semana y día/mes', () {
    final date = DateTime(2026, 11, 13);

    expect(formatWeekdayShort(date), 'Vie');
    expect(formatDayMonth(date), '13 nov');
    expect(formatShortDate(date), 'Vie 13 nov');
  });
}
