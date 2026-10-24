/// Formatea una medida sin decimales innecesarios (1.0 -> "1", 0.5 -> "0.5").
String formatMeasure(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Imagen de cada grupo de variantes, por nombre. Si un grupo no aparece aquí
/// (o el archivo no existe), la UI muestra un placeholder.
const Map<String, String> kGroupImages = {
  'Cruzcampo': 'lib/img/cruzcampo.jfif',
  'Aquarius': 'lib/img/aquarius.png',
  'Coca-Cola': 'lib/img/coca-cola.png',
  'Nestea': 'lib/img/fuze-tea.png',
  'Bliss': 'lib/img/royal-bliss.jpg',
};

/// Tipo de caja: nombre, unidades por caja, medidas (tamaño, altura, ancho),
/// formato y cuántas cajas caben en un viaje.
///
/// Agrupa los atributos físicos que comparten varios productos (p. ej. todas
/// las Coca-Cola usan la caja "Cola"). En la BD es la tabla `box`, identificada
/// por su `name` (campo `type`).
class CrateType {
  final int? id;
  final String name;
  final int units; // botellines por caja
  final double size; // tamaño
  final double height; // altura
  final double width; // ancho
  final int format; // formato
  final int trip; // cajas de este tipo por viaje

  const CrateType(
    this.name,
    this.units,
    this.size,
    this.height,
    this.format,
    this.trip, {
    this.width = 1,
    this.id,
  });

  CrateType copyWith({
    int? id,
    String? name,
    int? units,
    double? size,
    double? height,
    double? width,
    int? format,
    int? trip,
  }) =>
      CrateType(
        name ?? this.name,
        units ?? this.units,
        size ?? this.size,
        height ?? this.height,
        format ?? this.format,
        trip ?? this.trip,
        width: width ?? this.width,
        id: id ?? this.id,
      );

  String get info => '${name.isEmpty ? "Caja" : name} · $units uds · '
      'T${formatMeasure(size)} A${formatMeasure(height)} '
      'An${formatMeasure(width)} F$format · $trip/viaje';
}

/// Producto del catálogo. `category`, `groupName` y `subcategory` son datos de
/// lectura que se rellenan desde `product_group`/`category`/`subcategory`; la
/// caja ([box]) agrupa los atributos físicos compartidos.
class Product {
  final int? id;
  final String name;
  final String category; // categoría del grupo al que pertenece
  final String? groupName; // grupo de variantes (obligatorio en la BD)
  final String? subcategory; // variante dentro del grupo (opcional)
  final String? image;
  final String? groupImage; // imagen del grupo de variantes (compartida)
  final CrateType box;
  final int unitInStock; // unidades físicas disponibles
  final bool deleted; // borrado lógico

  Product({
    this.id,
    required this.name,
    this.category = 'Otros',
    this.groupName,
    this.subcategory,
    this.image,
    this.groupImage,
    CrateType? box,
    this.unitInStock = 0,
    this.deleted = false,
  }) : box = box ?? const CrateType('Caja', 24, 1, 1, 1, 5);

  // Atajos a los atributos de la caja, para no cambiar a quien ya los leía.
  int get unitsPerBox => box.units;
  double get size => box.size;
  double get height => box.height;
  double get width => box.width;
  int get format => box.format;
  String get crateName => box.name;
  int get tripCapacity => box.trip;

  /// Cajas completas que se pueden formar con [unitInStock].
  int get stockBoxes => unitsPerBox > 0 ? unitInStock ~/ unitsPerBox : 0;

  /// Unidades que sobran después de completar las cajas.
  int get stockLooseUnits =>
      unitsPerBox > 0 ? unitInStock % unitsPerBox : unitInStock;

  String? get validationError {
    if (name.trim().isEmpty) return 'El nombre es obligatorio.';
    if (category.trim().isEmpty) return 'La categoría es obligatoria.';
    if (groupName == null || groupName!.trim().isEmpty) {
      return 'El grupo de variantes es obligatorio.';
    }
    if (unitsPerBox <= 0) {
      return 'Las unidades por caja deben ser mayores que 0.';
    }
    if (!size.isFinite ||
        !height.isFinite ||
        !width.isFinite ||
        size <= 0 ||
        height <= 0 ||
        width <= 0) {
      return 'Tamaño, altura y ancho deben ser valores finitos mayores que 0.';
    }
    if (format <= 0) return 'El formato debe ser mayor que 0.';
    if (tripCapacity <= 0) {
      return 'Las cajas por viaje deben ser mayores que 0.';
    }
    if (unitInStock < 0) {
      return 'Las unidades en stock no pueden ser negativas.';
    }
    return null;
  }

  /// Construye un producto a partir de la fila del JOIN de `Db.products()`.
  factory Product.fromRow(Map<String, Object?> m) => Product(
        id: m['id'] as int,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'Otros',
        groupName: m['group_name'] as String?,
        subcategory: m['subcategory'] as String?,
        image: m['image'] as String?,
        groupImage: m['group_image'] as String?,
        unitInStock: (m['unit_in_stock'] as int?) ?? 0,
        deleted: m['deleted_at'] != null,
        box: CrateType(
          (m['box_name'] as String?) ?? 'Caja',
          (m['units_per_box'] as int?) ?? 24,
          ((m['size'] as num?) ?? 1).toDouble(),
          ((m['height'] as num?) ?? 1).toDouble(),
          (m['format'] as int?) ?? 1,
          (m['trip_capacity'] as int?) ?? 5,
          width: ((m['width'] as num?) ?? 1).toDouble(),
        ),
      );

  String get boxInfo => box.info;
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
