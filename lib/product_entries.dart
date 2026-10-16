import 'models.dart';

/// Entrada del catálogo en la lista de la noche: o un producto suelto, o un
/// grupo de variantes que se despliega.
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
}

/// Agrupa los productos (ya filtrados por categoría) para la lista.
///
/// Reglas:
/// - Un producto **sin grupo** se muestra suelto.
/// - Un grupo **solo se despliega si reúne a más de un producto**; los grupos
///   de uno (p. ej. una cerveza con grupo = su nombre) van sueltos.
/// - El desplegable incluye **todos** los miembros del grupo, tengan o no
///   subcategoría, usando [ProductEntry.label] como etiqueta. Así una variante
///   sin subcategoría nunca desaparece del grupo.
/// - **Orden**: primero los grupos de variantes (2 o más subcategorías) y
///   después los productos sueltos, conservando el orden relativo en cada parte.
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
      ..sort((a, b) => ProductEntry.label(a).compareTo(ProductEntry.label(b)));

    if (variants.length > 1) {
      groups.add(ProductEntry.group(group, variants));
    } else {
      singles.add(ProductEntry.product(product));
    }
  }

  return [...groups, ...singles];
}
