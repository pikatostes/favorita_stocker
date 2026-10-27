import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/screens/admin/admin.dart';

void main() {
  test('Admin agrupa Calendario, Previsión, Productos e Inventario', () {
    expect(
      AdminTab.values.map((tab) => tab.label),
      ['Calendario', 'Previsión', 'Productos', 'Inventario'],
    );
  });
}
