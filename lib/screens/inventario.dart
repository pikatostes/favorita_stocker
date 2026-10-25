import 'package:flutter/material.dart';

import '../models.dart';
import '../product_entries.dart';
import '../widgets/app_logo.dart';
import '../widgets/product_catalog.dart';

/// Listado de todo el catálogo con el stock disponible.
///
/// La base de datos guarda unidades sueltas; la tarjeta de cada producto las
/// convierte en cajas completas más las unidades que sobran.
class InventarioScreen extends StatelessWidget {
  /// Cuando se muestra dentro de [AdminScreen] no crea AppBar propia.
  final bool embedded;

  const InventarioScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: embedded ? null : AppBar(title: const AppLogo()),
        body: ProductCatalog(
          emptyMessage: 'No hay productos.',
          headerBuilder: _header,
          productSubtitle: (product) =>
              '${product.crateName} · ${product.unitsPerBox} uds/caja',
          trailingBuilder: (_, product, __) =>
              _StockSummary.forProduct(product),
          groupTrailingBuilder: (context, entry) =>
              _groupStockSummary(context, entry),
        ),
      );

  Widget _header(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '${products.length} productos · stock en cajas completas + uds',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Stock total de un grupo cuando todas sus variantes comparten tipo de caja.
///
/// Si el grupo mezcla cajas distintas, no se puede expresar como un único
/// número de cajas: en ese caso se muestran las unidades totales.
Widget _groupStockSummary(BuildContext context, ProductEntry entry) {
  final total = entry.products.fold<int>(
    0,
    (sum, product) => sum + product.unitInStock,
  );
  final crates = entry.products
      .map((product) => '${product.crateName}\u0000${product.unitsPerBox}')
      .toSet();
  if (crates.length == 1) {
    final perBox = entry.products.first.unitsPerBox;
    return _StockSummary(
      boxes: perBox > 0 ? total ~/ perBox : 0,
      loose: perBox > 0 ? total % perBox : total,
    );
  }
  return Text(
    '$total uds',
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
  );
}

/// Cajas completas y unidades sobrantes.
class _StockSummary extends StatelessWidget {
  final int boxes;
  final int loose;

  const _StockSummary({required this.boxes, required this.loose});

  factory _StockSummary.forProduct(Product product) => _StockSummary(
        boxes: product.stockBoxes,
        loose: product.stockLooseUnits,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
