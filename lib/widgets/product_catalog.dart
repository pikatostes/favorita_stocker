import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../product_entries.dart';
import 'category_tabs.dart';

/// Constructor del contenido a la derecha de una fila de producto.
///
/// [inOverlay] es `true` cuando la fila se pinta dentro de la tarjeta de
/// subcategorías, para que la pantalla pueda, por ejemplo, cerrar la tarjeta
/// antes de abrir un formulario o un diálogo de borrado.
typedef ProductCatalogTrailingBuilder = Widget? Function(
  BuildContext context,
  Product product,
  bool inOverlay,
);

/// Constructor del contenido a la derecha de una fila de grupo de variantes.
typedef ProductCatalogGroupTrailingBuilder = Widget? Function(
  BuildContext context,
  ProductEntry entry,
);

/// Constructor de la cabecera opcional que se muestra encima de las pestañas.
typedef ProductCatalogHeaderBuilder = Widget Function(
  BuildContext context,
  List<Product> products,
);

/// Listado reutilizable de productos con pestañas por categoría.
///
/// - Carga los productos de la base de datos y se actualiza al cambiar [Db.i].
/// - Agrupa las variantes de un mismo grupo. En la lista solo aparece una fila
///   por grupo con el número total de subcategorías; al pulsarla se abre una
///   tarjeta superpuesta con las variantes.
/// - Usa `ListView.builder`, así que no construye todas las filas de golpe.
class ProductCatalog extends StatefulWidget {
  final String emptyMessage;
  final String errorMessage;
  final EdgeInsets listPadding;
  final ProductCatalogHeaderBuilder? headerBuilder;
  final ValueChanged<String>? onCategoryChanged;
  final ValueChanged<Product>? onProductTap;
  final String Function(Product product)? productSubtitle;
  final String Function(Product product)? variantSubtitle;
  final ProductCatalogTrailingBuilder? trailingBuilder;
  final ProductCatalogGroupTrailingBuilder? groupTrailingBuilder;
  final bool refreshable;

  const ProductCatalog({
    super.key,
    this.emptyMessage = 'No hay productos.',
    this.errorMessage = 'No se pudieron cargar los productos',
    this.listPadding = const EdgeInsets.only(bottom: 24),
    this.headerBuilder,
    this.onCategoryChanged,
    this.onProductTap,
    this.productSubtitle,
    this.variantSubtitle,
    this.trailingBuilder,
    this.groupTrailingBuilder,
    this.refreshable = true,
  });

  @override
  State<ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<ProductCatalog> {
  late Future<List<Product>> _future = Db.i.products();

  void _reload() {
    if (mounted) setState(() => _future = Db.i.products());
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = Db.i.products();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${widget.errorMessage}: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return Center(child: Text(widget.emptyMessage));
          }

          final tabs = CategoryTabs(
            products: products,
            onCategory: widget.onCategoryChanged,
            builder: (_, inCategory) => _CategoryList(
              products: inCategory,
              listPadding: widget.listPadding,
              onRefresh: widget.refreshable ? _refresh : null,
              onProductTap: widget.onProductTap,
              productSubtitle: widget.productSubtitle,
              variantSubtitle: widget.variantSubtitle,
              trailingBuilder: widget.trailingBuilder,
              groupTrailingBuilder: widget.groupTrailingBuilder,
            ),
          );

          final header = widget.headerBuilder?.call(context, products);
          if (header == null) return tabs;
          return Column(
            children: [
              header,
              Expanded(child: tabs),
            ],
          );
        },
      );
}

/// Lista de una categoría concreta.
class _CategoryList extends StatelessWidget {
  final List<Product> products;
  final EdgeInsets listPadding;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Product>? onProductTap;
  final String Function(Product product)? productSubtitle;
  final String Function(Product product)? variantSubtitle;
  final ProductCatalogTrailingBuilder? trailingBuilder;
  final ProductCatalogGroupTrailingBuilder? groupTrailingBuilder;

  const _CategoryList({
    required this.products,
    required this.listPadding,
    required this.onRefresh,
    required this.onProductTap,
    required this.productSubtitle,
    required this.variantSubtitle,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final entries = buildProductEntries(products);
    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: listPadding,
      itemCount: entries.length,
      itemBuilder: (context, index) => _EntryTile(
        entry: entries[index],
        onProductTap: onProductTap,
        productSubtitle: productSubtitle,
        variantSubtitle: variantSubtitle,
        trailingBuilder: trailingBuilder,
        groupTrailingBuilder: groupTrailingBuilder,
      ),
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Fila de un producto suelto o de un grupo de variantes.
class _EntryTile extends StatelessWidget {
  final ProductEntry entry;
  final ValueChanged<Product>? onProductTap;
  final String Function(Product product)? productSubtitle;
  final String Function(Product product)? variantSubtitle;
  final ProductCatalogTrailingBuilder? trailingBuilder;
  final ProductCatalogGroupTrailingBuilder? groupTrailingBuilder;

  const _EntryTile({
    required this.entry,
    required this.onProductTap,
    required this.productSubtitle,
    required this.variantSubtitle,
    required this.trailingBuilder,
    required this.groupTrailingBuilder,
  });

  Future<void> _openVariants(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => _VariantsDialog(
          entry: entry,
          onProductTap: onProductTap,
          variantSubtitle: variantSubtitle,
          trailingBuilder: trailingBuilder,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!entry.isGroup) {
      final product = entry.products.single;
      return ListTile(
        leading: _ProductThumb(
          path: _productImage(product),
          isGroup: false,
        ),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          productSubtitle?.call(product) ?? product.boxInfo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailingBuilder?.call(context, product, false),
        onTap: onProductTap == null ? null : () => onProductTap!(product),
      );
    }

    final groupTrailing = groupTrailingBuilder?.call(context, entry);
    return ListTile(
      leading: _ProductThumb(path: entry.image, isGroup: true),
      title: Text(
        entry.groupName!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_groupSubtitle(entry.products.length)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (groupTrailing != null) ...[
            groupTrailing,
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _openVariants(context),
    );
  }
}

/// Tarjeta superpuesta con las subcategorías de un grupo de variantes.
class _VariantsDialog extends StatelessWidget {
  final ProductEntry entry;
  final ValueChanged<Product>? onProductTap;
  final String Function(Product product)? variantSubtitle;
  final ProductCatalogTrailingBuilder? trailingBuilder;

  const _VariantsDialog({
    required this.entry,
    required this.onProductTap,
    required this.variantSubtitle,
    required this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ProductThumb(path: entry.image, isGroup: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.groupName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          _groupSubtitle(entry.products.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entry.products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = entry.products[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _ProductThumb(
                        path: _productImage(product),
                        isGroup: false,
                        size: 40,
                      ),
                      title: Text(
                        ProductEntry.label(product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        variantSubtitle?.call(product) ??
                            _defaultVariantSubtitle(product),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: trailingBuilder?.call(context, product, true),
                      onTap: onProductTap == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              onProductTap!(product);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura del producto o del grupo, con placeholder si no hay imagen.
class _ProductThumb extends StatelessWidget {
  final String? path;
  final bool isGroup;
  final double size;

  const _ProductThumb({
    required this.path,
    required this.isGroup,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleaned = path?.trim();
    final fallback = Icon(
      isGroup ? Icons.category_outlined : Icons.local_drink_outlined,
      size: size * 0.6,
      color: theme.colorScheme.onSecondaryContainer,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: cleaned == null || cleaned.isEmpty
          ? fallback
          : Image.asset(
              cleaned,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

String _groupSubtitle(int count) =>
    '$count ${count == 1 ? 'subcategoría' : 'subcategorías'}';

String? _productImage(Product product) {
  final own = product.image?.trim();
  if (own != null && own.isNotEmpty) return own;
  final group = product.groupImage?.trim();
  return group != null && group.isNotEmpty ? group : null;
}

String _defaultVariantSubtitle(Product product) {
  final label = ProductEntry.label(product);
  return label == product.name
      ? product.boxInfo
      : '${product.name} · ${product.boxInfo}';
}
