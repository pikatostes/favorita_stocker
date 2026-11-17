import 'models.dart';

/// Entrada del catálogo: o un producto suelto, o un grupo de variantes que se
/// muestra como una sola fila y se despliega en una tarjeta.
class ProductEntry {
  final String? groupName;
  final List<Product> products;

  ProductEntry.product(Product product)
      : groupName = null,
        products = [product];

  const ProductEntry.group(this.groupName, this.products);

  bool get isGroup => groupName != null;

  /// Imagen para la cuadrícula: la del grupo si es un grupo de variantes, o la
  /// del propio producto si va suelto. Si el grupo no tiene imagen propia (por
  /// ejemplo, un tipo de alcohol), se usa la de la primera botella. `null` si no
  /// hay (la UI pone placeholder).
  String? get image {
    if (!isGroup) return products.single.image;
    for (final product in products) {
      final path = product.groupImage?.trim();
      if (path != null && path.isNotEmpty) return path;
    }
    if (products.first.isBottle) {
      for (final product in products) {
        final own = product.image?.trim();
        if (own != null && own.isNotEmpty) return own;
      }
    }
    return null;
  }

  /// Etiqueta visible de un producto dentro de su grupo: **siempre** su nombre.
  ///
  /// La subcategoría (marca, variante…) no se usa como título para que cada
  /// fila muestre el nombre real del producto; la UI la enseña en el subtítulo.
  static String label(Product product) => product.name;

  /// Nombre visible de la entrada: el del grupo si es un grupo de variantes, o
  /// el del producto suelto.
  String get sortLabel => _sortKey(groupName ?? products.first.name);
}

/// Clave de ordenación alfabética: minúsculas y sin tildes, para que "Ámbar"
/// quede junto a "ambar" y no detrás de la "z".
String _sortKey(String value) {
  const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final index = accents.indexOf(String.fromCharCode(rune));
    buffer.write(index < 0 ? String.fromCharCode(rune) : plain[index]);
  }
  return buffer.toString().trim();
}

/// Subgrupo de variantes dentro de un grupo: en las botellas de alcohol, la
/// marca (`subcategory`). [name] vacío significa «sin marca».
class ProductSubgroup {
  final String name;
  final List<Product> products;

  const ProductSubgroup(this.name, this.products);

  bool get hasName => name.isNotEmpty;
}

/// Clave y etiqueta con la que se agrupa un producto: su **grupo de producto**
/// (`groupName`). Las botellas de alcohol se agrupan igual por tipo (Ron,
/// Whisky…); dentro de cada tipo, [buildProductSubgroups] las separa por marca.
({String key, String label}) _groupOf(Product product) {
  final group = product.groupName?.trim() ?? '';
  return (key: group, label: group);
}

/// Separa las variantes de un grupo de **botellas de alcohol** por **marca**
/// (`subcategory`), para mostrarlas en secciones dentro del tipo.
///
/// Devuelve una lista vacía cuando no procede: no es un grupo de botellas o
/// ninguna tiene marca. Las marcas van ordenadas alfabéticamente (sin
/// mayúsculas ni tildes) y las botellas de cada marca por su nombre. Las
/// botellas sin marca, si las hay, van al final en un subgrupo sin título.
List<ProductSubgroup> buildProductSubgroups(ProductEntry entry) {
  if (!entry.isGroup || entry.products.isEmpty) return const [];
  if (!entry.products.every((product) => product.isBottle)) return const [];

  final grouped = <String, List<Product>>{};
  for (final product in entry.products) {
    final brand = product.subcategory?.trim() ?? '';
    grouped.putIfAbsent(brand, () => []).add(product);
  }
  if (!grouped.keys.any((brand) => brand.isNotEmpty)) return const [];

  final brands = grouped.keys.where((brand) => brand.isNotEmpty).toList()
    ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  if (grouped.containsKey('')) brands.add('');

  return [
    for (final brand in brands)
      ProductSubgroup(brand, _sortProducts(grouped[brand]!)),
  ];
}

List<Product> _sortProducts(List<Product> products) => products
  ..sort((a, b) => _sortKey(ProductEntry.label(a))
      .compareTo(_sortKey(ProductEntry.label(b))));

/// Agrupa los productos (ya filtrados por categoría) para una lista.
///
/// Reglas:
/// - Un producto **sin grupo** se muestra suelto.
/// - Todos los productos se agrupan por su **grupo de producto** (`groupName`),
///   incluidas las botellas de alcohol (Ron, Whisky…). Dentro de un grupo de
///   botellas, [buildProductSubgroups] las separa por marca (`subcategory`).
/// - Un grupo **solo se despliega si reúne a más de un producto**; los grupos
///   de uno (p. ej. una cerveza con grupo = su nombre) van sueltos.
/// - El desplegable incluye **todos** los miembros del grupo, tengan o no
///   subcategoría, usando [ProductEntry.label] (el nombre) como etiqueta.
/// - **Orden**: alfabético por el nombre visible ([ProductEntry.sortLabel]),
///   sin distinguir mayúsculas ni tildes. Grupos de variantes y productos
///   sueltos van entremezclados; las variantes de un grupo se ordenan por su
///   etiqueta con el mismo criterio.
List<ProductEntry> buildProductEntries(List<Product> products) {
  final groups = <ProductEntry>[];
  final singles = <ProductEntry>[];
  final renderedGroups = <String>{};

  for (final product in products) {
    final grouping = _groupOf(product);
    if (grouping.key.isEmpty) {
      singles.add(ProductEntry.product(product));
      continue;
    }

    final groupKey = '${product.category}\u0000${grouping.key}';
    if (!renderedGroups.add(groupKey)) continue;

    final variants = products
        .where((candidate) =>
            candidate.category == product.category &&
            _groupOf(candidate).key == grouping.key)
        .toList()
      ..sort((a, b) => _sortKey(ProductEntry.label(a))
          .compareTo(_sortKey(ProductEntry.label(b))));

    if (variants.length > 1) {
      groups.add(ProductEntry.group(grouping.label, variants));
    } else {
      singles.add(ProductEntry.product(product));
    }
  }

  return [...groups, ...singles]..sort((a, b) {
      final byLabel = a.sortLabel.compareTo(b.sortLabel);
      if (byLabel != 0) return byLabel;
      // Desempate estable cuando grupo y producto comparten nombre visible.
      final byGroup = (a.groupName ?? '').compareTo(b.groupName ?? '');
      if (byGroup != 0) return byGroup;
      return (a.products.first.id ?? 0).compareTo(b.products.first.id ?? 0);
    });
}
