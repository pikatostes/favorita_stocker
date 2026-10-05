class Product {
  final int? id;
  final String name;
  final String category;
  final int unitsPerBox; // botellines por caja
  final double size; // tamaño
  final double height; // altura
  final int format; // formato
  final String crateName; // tipo de caja (Cerveza, Cola, Nestea...)
  final int tripCapacity; // cuántas cajas de este tipo caben en un viaje

  Product({
    this.id,
    required this.name,
    this.category = 'Otros',
    this.unitsPerBox = 24,
    this.size = 1,
    this.height = 1,
    this.format = 1,
    this.crateName = '',
    this.tripCapacity = 5,
  });

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'Otros',
        unitsPerBox: m['units_per_box'] as int,
        size: ((m['size'] as num?) ?? 1).toDouble(),
        height: ((m['height'] as num?) ?? 1).toDouble(),
        format: (m['format'] as int?) ?? 1,
        crateName: (m['crate_name'] as String?) ?? '',
        tripCapacity: (m['trip_capacity'] as int?) ?? 5,
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'category': category,
        'units_per_box': unitsPerBox,
        'size': size,
        'height': height,
        'format': format,
        'crate_name': crateName,
        'trip_capacity': tripCapacity,
      };

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String get boxInfo =>
      '${crateName.isEmpty ? "Caja" : crateName} · $unitsPerBox uds · '
      'T${_n(size)} A${_n(height)} F$format · $tripCapacity/viaje';
}

/// Excepción al calendario habitual: festivo en que SÍ se abre (open=true)
/// o un viernes/sábado en que NO se abre (open=false).
class SpecialDay {
  final String date; // yyyy-MM-dd
  final bool open;
  final String note;
  SpecialDay(this.date, {required this.open, this.note = ''});

  factory SpecialDay.fromMap(Map<String, Object?> m) => SpecialDay(
        m['date'] as String,
        open: (m['open'] as int) == 1,
        note: (m['note'] as String?) ?? '',
      );
}

class Forecast {
  final Product product;
  final int units; // unidades previstas (con margen)
  Forecast(this.product, this.units);

  int get boxes => (units / product.unitsPerBox).ceil();
}

class ForecastResult {
  final List<Forecast> items;
  final int recentNights; // noches recientes usadas como base
  final int seasonalYears; // años previos usados para el ajuste de temporada
  ForecastResult(this.items, this.recentNights, this.seasonalYears);
}
