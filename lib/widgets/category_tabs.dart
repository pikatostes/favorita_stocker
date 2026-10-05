import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models.dart';

/// Pestañas por categoría de producto (Cervezas y similares, Refrescos...).
/// Las categorías salen de los propios productos.
class CategoryTabs extends StatefulWidget {
  final List<Product> products;
  final Widget Function(BuildContext context, List<Product> inCategory) builder;

  /// Texto extra en cada pestaña, p. ej. " (3)".
  final String Function(String category)? badge;

  /// Se llama con la categoría visible al cambiar de pestaña.
  final ValueChanged<String>? onCategory;

  const CategoryTabs({
    super.key,
    required this.products,
    required this.builder,
    this.badge,
    this.onCategory,
  });

  @override
  State<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<CategoryTabs>
    with TickerProviderStateMixin {
  TabController? _c;
  List<String> _cats = [];

  List<String> _compute() {
    final out = <String>[];
    for (final p in widget.products) {
      if (!out.contains(p.category)) out.add(p.category);
    }
    return out;
  }

  void _setup() {
    final cats = _compute();
    if (_c != null && listEquals(cats, _cats)) return;
    final old = _c?.index ?? 0;
    _c?.dispose();
    _cats = cats;
    if (cats.isEmpty) {
      _c = null;
      return;
    }
    final c = TabController(
        length: cats.length,
        vsync: this,
        initialIndex: old.clamp(0, cats.length - 1));
    c.addListener(() => widget.onCategory?.call(_cats[c.index]));
    _c = c;
    widget.onCategory?.call(_cats[c.index]);
  }

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant CategoryTabs old) {
    super.didUpdateWidget(old);
    _setup();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return Column(children: [
      TabBar(
        controller: c,
        tabs: [
          for (final cat in _cats)
            Tab(text: '$cat${widget.badge?.call(cat) ?? ""}'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: c,
          children: [
            for (final cat in _cats)
              widget.builder(
                  context, widget.products.where((p) => p.category == cat).toList()),
          ],
        ),
      ),
    ]);
  }
}
