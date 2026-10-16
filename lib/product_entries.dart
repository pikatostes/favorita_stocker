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
List<ProductEntry> buildProductEntries(List<Product> products) {
  final entries = <ProductEntry>[];
  final renderedGroups = <String>{};

  for (final product in products) {
    final group = product.groupName?.trim() ?? '';
    if (group.isEmpty) {
      entries.add(ProductEntry.product(product));
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

    entries.add(variants.length > 1
        ? ProductEntry.group(group, variants)
        : ProductEntry.product(product));
  }
  return entries;
}
