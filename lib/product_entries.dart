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
  /// del propio producto si va suelto. `null` si no hay (la UI pone placeholder).
  String? get image {
    if (!isGroup) return products.single.image;
    for (final product in products) {
      final path = product.groupImage?.trim();
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }

  /// Etiqueta de un producto dentro de su grupo: la subcategoría si la tiene,
  /// y si no el nombre, para no perder ninguna variante.
  static String label(Product product) {
    final subcategory = product.subcategory?.trim() ?? '';
    return subcategory.isEmpty ? product.name : subcategory;
  }

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

/// Agrupa los productos (ya filtrados por categoría) para una lista.
///
/// Reglas:
/// - Un producto **sin grupo** se muestra suelto.
/// - Un grupo **solo se despliega si reúne a más de un producto**; los grupos
///   de uno (p. ej. una cerveza con grupo = su nombre) van sueltos.
/// - El desplegable incluye **todos** los miembros del grupo, tengan o no
///   subcategoría, usando [ProductEntry.label] como etiqueta. Así una variante
///   sin subcategoría nunca desaparece del grupo.
/// - **Orden**: alfabético por el nombre visible ([ProductEntry.sortLabel]),
///   sin distinguir mayúsculas ni tildes. Grupos de variantes y productos
///   sueltos van entremezclados; las variantes de un grupo se ordenan por su
///   etiqueta con el mismo criterio.
List<ProductEntry> buildProductEntries(List<Product> products) {
  final groups = <ProductEntry>[];
  final singles = <ProductEntry>[];
  final renderedGroups = <String>{};

  for (final product in products) {
    final group = product.groupName?.trim() ?? '';
    if (group.isEmpty) {
      singles.add(ProductEntry.product(product));
      continue;
    }

    final groupKey = '${product.category}\u0000$group';
    if (!renderedGroups.add(groupKey)) continue;

    final variants = products
        .where((candidate) =>
            candidate.category == product.category &&
            (candidate.groupName?.trim() ?? '') == group)
        .toList()
      ..sort((a, b) => _sortKey(ProductEntry.label(a))
          .compareTo(_sortKey(ProductEntry.label(b))));

    if (variants.length > 1) {
      groups.add(ProductEntry.group(group, variants));
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
