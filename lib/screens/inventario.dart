import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets/app_logo.dart';

/// Listado de todo el catálogo con el stock disponible.
///
/// La base de datos guarda unidades sueltas; aquí se convierten en cajas
/// completas más las unidades que sobran, usando [Product.stockBoxes] y
/// [Product.stockLooseUnits].
class InventarioScreen extends StatefulWidget {
  /// Cuando se muestra dentro de [AdminScreen] no crea AppBar propia.
  final bool embedded;

  const InventarioScreen({super.key, this.embedded = false});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
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
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const AppLogo()),
        body: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudo cargar el inventario: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final products = snapshot.data!;
            if (products.isEmpty) {
              return const Center(child: Text('No hay productos.'));
            }
            return _list(context, products);
          },
        ),
      );

  Widget _list(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final product in products) {
      counts[product.category] = (counts[product.category] ?? 0) + 1;
    }

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          '${products.length} productos · stock en cajas completas + uds',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];

    String? currentCategory;
    for (final product in products) {
      if (product.category != currentCategory) {
        currentCategory = product.category;
        children.add(
          _categoryHeader(
            context,
            currentCategory,
            counts[currentCategory] ?? 0,
          ),
        );
      }
      children.add(_productTile(context, product));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }

  Widget _categoryHeader(
    BuildContext context,
    String category,
    int count,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: const Icon(Icons.inventory_2_outlined, size: 20),
      ),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${product.crateName} · ${product.unitsPerBox} uds/caja',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _StockSummary(product: product),
    );
  }
}

/// Cajas completas y unidades sobrantes de un producto.
class _StockSummary extends StatelessWidget {
  final Product product;

  const _StockSummary({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boxes = product.stockBoxes;
    final loose = product.stockLooseUnits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$boxes ${boxes == 1 ? 'caja' : 'cajas'}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '+ $loose uds',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
