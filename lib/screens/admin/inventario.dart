import 'package:flutter/material.dart';

import '../../app_design.dart';
import '../../db.dart';
import '../../models.dart';
import '../../product_entries.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/product_catalog.dart';
import '../../widgets/quantity_stepper.dart';

/// Listado de todo el catálogo con el stock disponible.
///
/// La base de datos guarda unidades sueltas; la tarjeta de cada producto las
/// convierte en cajas completas más las unidades que sobran. El administrador
/// puede subir o bajar el stock con los botones de cada fila o abriendo el
/// diálogo de ajuste (útil para movimientos grandes).
///
/// Un selector alterna entre el stock general del local y el de la terraza: la
/// lista de la planta Terraza descuenta del suyo automáticamente.
class InventarioScreen extends StatefulWidget {
  /// Cuando se muestra dentro de [AdminScreen] no crea AppBar propia.
  final bool embedded;

  const InventarioScreen({super.key, this.embedded = false});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  /// `false` = stock general; `true` = stock de la terraza.
  bool _terrace = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const AppLogo()),
        body: ProductCatalog(
          emptyMessage: 'No hay productos.',
          headerBuilder: _header,
          productSubtitle: (product) => product.isBottle
              ? 'Botella · se cuenta por unidades'
              : '${product.crateName} · ${product.unitsPerBox} uds/caja',
          trailingBuilder: (_, product, inOverlay) => _StockTrail(
            product: product,
            compact: inOverlay,
            terrace: _terrace,
          ),
          groupTrailingBuilder: (context, entry) =>
              _groupStockSummary(context, entry, terrace: _terrace),
        ),
      );

  Widget _header(BuildContext context, List<Product> products) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('General'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.deck_outlined),
                  label: Text('Terraza'),
                ),
              ],
              selected: {_terrace},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _terrace = selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${products.length} productos · '
            '${_terrace ? 'stock de terraza' : 'stock general'} · '
            'toca el stock para ajustarlo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stock total de un grupo cuando todas sus variantes comparten tipo de caja.
///
/// Si el grupo mezcla cajas distintas, no se puede expresar como un único
/// número de cajas: en ese caso se muestran las unidades totales.
Widget _groupStockSummary(
  BuildContext context,
  ProductEntry entry, {
  bool terrace = false,
}) {
  final total = entry.products.fold<int>(
    0,
    (sum, product) =>
        sum + (terrace ? product.unitInTerraceStock : product.unitInStock),
  );
  final crates = entry.products
      .map((product) => '${product.crateName}\u0000${product.unitsPerBox}')
      .toSet();
  if (entry.products.every((product) => product.isBottle)) {
    return _StockSummary(boxes: total, loose: 0, bottles: true);
  }
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

/// Cajas completas y unidades sobrantes (o botellas sueltas de alcohol).
class _StockSummary extends StatelessWidget {
  final int boxes;
  final int loose;

  /// `true` para mostrar «N botellas» en lugar de cajas + sueltas.
  final bool bottles;

  const _StockSummary({
    required this.boxes,
    required this.loose,
    this.bottles = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          bottles
              ? '$boxes ${boxes == 1 ? 'botella' : 'botellas'}'
              : '$boxes ${boxes == 1 ? 'caja' : 'cajas'}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!bottles)
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

/// Control para subir o bajar el stock de un producto.
///
/// En la lista principal muestra «− resumen +» para mover una unidad por toque;
/// en la tarjeta de variantes se compacta a un resumen que abre el diálogo.
class _StockTrail extends StatefulWidget {
  final Product product;
  final bool compact;

  /// `true` para mover y mostrar el stock de la terraza.
  final bool terrace;

  const _StockTrail({
    required this.product,
    this.compact = false,
    this.terrace = false,
  });

  @override
  State<_StockTrail> createState() => _StockTrailState();
}

class _StockTrailState extends State<_StockTrail> {
  bool _busy = false;
  late int _stock;

  int get _unitsPerBox => widget.product.isBottle
      ? 1
      : (widget.product.unitsPerBox < 1 ? 1 : widget.product.unitsPerBox);

  int get _sourceStock => widget.terrace
      ? widget.product.unitInTerraceStock
      : widget.product.unitInStock;

  bool get _enabled => widget.product.id != null && !_busy;

  @override
  void initState() {
    super.initState();
    _stock = _sourceStock;
  }

  @override
  void didUpdateWidget(covariant _StockTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSource = oldWidget.terrace
        ? oldWidget.product.unitInTerraceStock
        : oldWidget.product.unitInStock;
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.terrace != widget.terrace ||
        oldSource != _sourceStock) {
      _stock = _sourceStock;
    }
  }

  Future<void> _apply(int delta) async {
    final id = widget.product.id;
    if (id == null || delta == 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final stock = await Db.i.adjustStock(id, delta, terrace: widget.terrace);
      if (mounted) setState(() => _stock = stock);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, describeDbError(error), tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDialog() async {
    if (!_enabled) return;
    final delta = await showDialog<int>(
      context: context,
      builder: (_) => _StockDialog(
        product: widget.product,
        stock: _stock,
        terrace: widget.terrace,
      ),
    );
    if (delta == null || delta == 0) return;
    await _apply(delta);
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: _busy ? null : onPressed,
        icon: Icon(icon, size: 19),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = widget.terrace ? ' de terraza' : '';
    final what = widget.product.isBottle ? 'una botella' : 'una unidad';
    final summary = Tooltip(
      message: 'Ajustar stock$suffix',
      child: InkWell(
        onTap: _enabled ? _openDialog : null,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StockSummary(
                boxes: _stock ~/ _unitsPerBox,
                loose: _stock % _unitsPerBox,
                bottles: widget.product.isBottle,
              ),
              if (widget.compact) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.compact) return summary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(
          icon: Icons.remove,
          tooltip: 'Quitar $what$suffix',
          onPressed: _stock > 0 ? () => _apply(-1) : null,
        ),
        summary,
        _iconButton(
          icon: Icons.add,
          tooltip: 'Añadir $what$suffix',
          onPressed: () => _apply(1),
        ),
      ],
    );
  }
}

/// Diálogo para ajustar el stock por cajas y unidades sueltas.
///
/// Devuelve la diferencia de unidades respecto al stock actual; el control que
/// lo abre llama a [Db.adjustStock] con ese delta.
class _StockDialog extends StatefulWidget {
  final Product product;
  final int stock;

  /// `true` si el diálogo ajusta el stock de la terraza.
  final bool terrace;

  const _StockDialog({
    required this.product,
    required this.stock,
    this.terrace = false,
  });

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late int _boxes;
  late int _loose;

  int get _unitsPerBox => widget.product.isBottle
      ? 1
      : (widget.product.unitsPerBox < 1 ? 1 : widget.product.unitsPerBox);
  int get _total => _boxes * _unitsPerBox + _loose;
  int get _delta => _total - widget.stock;

  @override
  void initState() {
    super.initState();
    if (widget.product.isBottle) {
      _boxes = 0;
      _loose = widget.stock;
    } else {
      _boxes = widget.stock ~/ _unitsPerBox;
      _loose = widget.stock % _unitsPerBox;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = widget.terrace ? ' de terraza' : '';
    final bottle = widget.product.isBottle;
    String units(int value) =>
        bottle ? '$value ${value == 1 ? 'botella' : 'botellas'}' : '$value uds';
    return AlertDialog(
      title: Text('Ajustar stock$suffix'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Stock actual$suffix: ${units(widget.stock)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (bottle)
              QuantityStepper(
                label: 'Botellas',
                value: _loose,
                onDecrement: _loose > 0 ? () => setState(() => _loose--) : null,
                onIncrement: () => setState(() => _loose++),
              )
            else
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  QuantityStepper(
                    label: 'Cajas',
                    hint: '$_unitsPerBox uds',
                    value: _boxes,
                    onDecrement:
                        _boxes > 0 ? () => setState(() => _boxes--) : null,
                    onIncrement: () => setState(() => _boxes++),
                  ),
                  QuantityStepper(
                    label: 'Sueltas',
                    value: _loose,
                    onDecrement:
                        _loose > 0 ? () => setState(() => _loose--) : null,
                    onIncrement: () => setState(() => _loose++),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nuevo total: ${units(_total)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _delta == 0
                  ? 'Sin cambios'
                  : _delta > 0
                      ? 'Se añaden ${units(_delta)}'
                      : 'Se quitan ${units(-_delta)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _delta == 0 ? null : () => Navigator.pop(context, _delta),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
