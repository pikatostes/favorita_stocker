import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
import '../widgets/category_tabs.dart';
import 'plan.dart';

class _ProductEntry {
  final String? groupName;
  final List<Product> products;

  _ProductEntry.product(Product product)
      : groupName = null,
        products = [product];

  const _ProductEntry.group(this.groupName, this.products);

  bool get isGroup => groupName != null;
}

/// Introducir la lista de lo gastado esa noche (la de las ~3:00).
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // La noche empieza a las 16:00: a las 3:00 sigue siendo la de "ayer".
  DateTime _date = Schedule.serviceDay(DateTime.now());
  final Map<int, int> _qty = {};
  bool _gridView = false;
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

  void _adjustQuantity(
    Product product,
    int change, {
    StateSetter? refreshOverlay,
  }) {
    final quantity = _qty[product.id] ?? 0;
    setState(() => _qty[product.id!] = (quantity + change).clamp(0, 1 << 31));
    refreshOverlay?.call(() {});
  }

  /// Botón compacto del contador. Se usa tanto para botellines sueltos
  /// (iconos perfilados) como para cajas completas (iconos rellenos).
  Widget _qtyButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        iconSize: 20,
        icon: Icon(icon),
        onPressed: onPressed,
      );

  Widget _quantityControls(Product product, {StateSetter? refreshOverlay}) {
    final quantity = _qty[product.id] ?? 0;
    final box = product.unitsPerBox < 1 ? 1 : product.unitsPerBox;
    void add(int change) =>
        _adjustQuantity(product, change, refreshOverlay: refreshOverlay);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _qtyButton(
        icon: Icons.remove_circle,
        tooltip: 'Quitar una caja (-$box)',
        onPressed: quantity >= box ? () => add(-box) : null,
      ),
      _qtyButton(
        icon: Icons.remove_circle_outline,
        tooltip: 'Quitar un botellín',
        onPressed: quantity > 0 ? () => add(-1) : null,
      ),
      SizedBox(
        width: 34,
        child: Text(
          '$quantity',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _qtyButton(
        icon: Icons.add_circle_outline,
        tooltip: 'Añadir un botellín',
        onPressed: () => add(1),
      ),
      _qtyButton(
        icon: Icons.add_circle,
        tooltip: 'Añadir una caja (+$box)',
        onPressed: () => add(box),
      ),
    ]);
  }

  Widget _productTile(
    Product product, {
    String? title,
    StateSetter? refreshOverlay,
  }) {
    return ListTile(
      title: Text(title ?? product.name),
      trailing: _quantityControls(
        product,
        refreshOverlay: refreshOverlay,
      ),
    );
  }

  List<_ProductEntry> _productEntries(List<Product> products) {
    final entries = <_ProductEntry>[];
    final renderedGroups = <String>{};
    for (final product in products) {
      final group = product.groupName?.trim();
      final subcategory = product.subcategory?.trim();
      if (group == null ||
          group.isEmpty ||
          subcategory == null ||
          subcategory.isEmpty) {
        entries.add(_ProductEntry.product(product));
        continue;
      }

      final groupKey = '${product.category}\u0000$group';
      if (!renderedGroups.add(groupKey)) continue;

      final variants = products
          .where((candidate) =>
              candidate.category == product.category &&
              candidate.groupName?.trim() == group &&
              (candidate.subcategory?.trim().isNotEmpty ?? false))
          .toList()
        ..sort((a, b) => a.subcategory!.compareTo(b.subcategory!));
      entries.add(_ProductEntry.group(group, variants));
    }
    return entries;
  }

  Future<void> _chooseVariants(_ProductEntry entry) async {
    final variants = entry.products;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshOverlay) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    entry.groupName!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final variant in variants)
                        _productTile(
                          variant,
                          title: variant.subcategory,
                          refreshOverlay: refreshOverlay,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupListTile(_ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + (_qty[product.id] ?? 0),
    );
    return ListTile(
      title: Text(entry.groupName!),
      subtitle: Text('${entry.products.length} variantes'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) Text('$count'),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more),
        ],
      ),
      onTap: () => _chooseVariants(entry),
    );
  }

  Widget _groupGridCard(_ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + (_qty[product.id] ?? 0),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _chooseVariants(entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.groupName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text('${entry.products.length} variantes'),
              Row(
                children: [
                  const Icon(Icons.expand_more, size: 20),
                  const Spacer(),
                  if (count > 0) Text('$count añadidos'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGridCard(Product product) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 96,
                child: product.image == null || product.image!.isEmpty
                    ? Icon(
                        Icons.local_drink_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.outline,
                      )
                    : Image.asset(
                        product.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _quantityControls(product),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _categoryList(List<Product> products) {
    final entries = _productEntries(products);
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        for (final entry in entries)
          if (entry.isGroup)
            _groupListTile(entry)
          else
            _productTile(entry.products.single),
      ],
    );
  }

  Widget _categoryGrid(List<Product> products) {
    final entries = _productEntries(products);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return entry.isGroup
            ? _groupGridCard(entry)
            : _productGridCard(entry.products.single);
      },
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: Schedule.retentionLimit(),
        lastDate: DateTime.now());
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_qty.values.every((q) => q == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade algún botellín a la lista')));
      return;
    }
    final qty = Map<int, int>.from(_qty);
    await Db.i.saveNight(Schedule.fmt(_date), qty);
    if (!mounted) return;
    setState(_qty.clear);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => PlanScreen(qty: qty)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lista de la noche'),
          actions: [
            IconButton(
              tooltip: 'Vista de lista',
              isSelected: !_gridView,
              icon: const Icon(Icons.view_list),
              selectedIcon: const Icon(Icons.view_list),
              onPressed: () => setState(() => _gridView = false),
            ),
            IconButton(
              tooltip: 'Vista de cuadrícula',
              isSelected: _gridView,
              icon: const Icon(Icons.grid_view),
              selectedIcon: const Icon(Icons.grid_view),
              onPressed: () => setState(() => _gridView = true),
            ),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat('EEE d MMM', 'es').format(_date)),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _save,
            icon: const Icon(Icons.inventory_2),
            label: const Text('Guardar y montar cajas')),
        body: FutureBuilder<List<Product>>(
          future: _future,
          builder: (_, s) {
            if (s.hasError) {
              return Center(
                  child:
                      Text('No se pudieron cargar los productos: ${s.error}'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.isEmpty) {
              return const Center(
                  child:
                      Text('Primero añade productos en la pestaña Productos'));
            }
            final products = s.data!;
            return CategoryTabs(
              products: products,
              badge: (category) {
                final count = products
                    .where((product) =>
                        product.category == category &&
                        (_qty[product.id] ?? 0) > 0)
                    .length;
                return count == 0 ? '' : ' ($count)';
              },
              builder: (_, categoryProducts) => _gridView
                  ? _categoryGrid(categoryProducts)
                  : _categoryList(categoryProducts),
            );
          },
        ),
      );
}
