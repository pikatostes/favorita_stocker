import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../product_entries.dart';
import '../schedule.dart';
import '../widgets/category_tabs.dart';
import 'plan.dart';

/// Introducir la lista de lo gastado esa noche (la de las ~3:00).
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // La noche empieza a las 16:00: a las 3:00 sigue siendo la de "ayer".
  DateTime _date = Schedule.serviceDay(DateTime.now());

  /// Cajas completas y botellines sueltos por producto. La cantidad se guarda
  /// siempre en botellines (cajas × unidades por caja + sueltos).
  final Map<int, int> _boxes = {};
  final Map<int, int> _loose = {};
  bool _gridView = false;
  late Future<List<Product>> _future = Db.i.products();

  void _reload() {
    if (mounted) setState(() => _future = Db.i.products());
  }

  int _boxSize(Product p) => p.unitsPerBox < 1 ? 1 : p.unitsPerBox;

  /// Total de botellines de un producto (cajas completas + sueltos).
  int _totalFor(Product p) =>
      (_boxes[p.id] ?? 0) * _boxSize(p) + (_loose[p.id] ?? 0);

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

  void _setBoxes(Product product, int value, {StateSetter? refreshOverlay}) {
    setState(() => _boxes[product.id!] = value < 0 ? 0 : value);
    refreshOverlay?.call(() {});
  }

  void _setLoose(Product product, int value, {StateSetter? refreshOverlay}) {
    setState(() => _loose[product.id!] = value < 0 ? 0 : value);
    refreshOverlay?.call(() {});
  }

  /// Botón compacto del contador (− / +).
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

  /// Una fila de contador: etiqueta, −, valor y +.
  Widget _counter({
    required String label,
    required int value,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 62,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        _qtyButton(
          icon: Icons.remove_circle_outline,
          tooltip: 'Quitar $label',
          onPressed: onMinus,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _qtyButton(
          icon: Icons.add_circle_outline,
          tooltip: 'Añadir $label',
          onPressed: onPlus,
        ),
      ]);

  /// Opción B: dos contadores separados (cajas completas y botellines sueltos)
  /// con el total en botellines debajo.
  Widget _quantityControls(Product product, {StateSetter? refreshOverlay}) {
    final unit = _boxSize(product);
    final boxes = _boxes[product.id] ?? 0;
    final loose = _loose[product.id] ?? 0;
    final total = boxes * unit + loose;
    final rows = <Widget>[];
    if (unit > 1) {
      rows.add(_counter(
        label: 'Cajas',
        value: boxes,
        onMinus: boxes > 0
            ? () => _setBoxes(product, boxes - 1, refreshOverlay: refreshOverlay)
            : null,
        onPlus: () =>
            _setBoxes(product, boxes + 1, refreshOverlay: refreshOverlay),
      ));
    }
    rows.add(_counter(
      label: unit > 1 ? 'Sueltos' : 'Botellines',
      value: loose,
      onMinus: loose > 0
          ? () => _setLoose(product, loose - 1, refreshOverlay: refreshOverlay)
          : null,
      onPlus: () =>
          _setLoose(product, loose + 1, refreshOverlay: refreshOverlay),
    ));
    rows.add(Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        unit > 1 ? 'Caja = $unit uds · Total $total' : 'Total $total',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: rows,
    );
  }

  Widget _productTile(
    Product product, {
    String? title,
    StateSetter? refreshOverlay,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(title ?? product.name)),
            const SizedBox(width: 12),
            _quantityControls(product, refreshOverlay: refreshOverlay),
          ],
        ),
      );

  Future<void> _chooseVariants(ProductEntry entry) async {
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
                          title: ProductEntry.label(variant),
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

  Widget _groupListTile(ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + _totalFor(product),
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

  /// Imagen de una tarjeta de cuadrícula, con placeholder si no hay archivo.
  Widget _gridThumb(String? path, IconData placeholder) {
    if (path == null || path.trim().isEmpty) {
      return Icon(placeholder,
          size: 42, color: Theme.of(context).colorScheme.outline);
    }
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        size: 42,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _groupGridCard(ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + _totalFor(product),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _chooseVariants(entry),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _gridThumb(entry.image, Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.groupName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.products.length} variantes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (count > 0)
                    Text('$count',
                        style: Theme.of(context).textTheme.labelLarge),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGridCard(Product product) {
    final unit = _boxSize(product);
    final boxes = _boxes[product.id] ?? 0;
    final loose = _loose[product.id] ?? 0;
    final total = boxes * unit + loose;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editQuantity(product),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _gridThumb(product.image, Icons.local_drink_outlined),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                total > 0 ? '$total botellines' : 'Sin añadir',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (total > 0 && unit > 1)
                Text(
                  '$boxes cajas · $loose sueltos',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Text(
                  'Toca para ajustar',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editQuantity(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshOverlay) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _quantityControls(product,
                      refreshOverlay: refreshOverlay),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
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

  Widget _categoryList(List<Product> products) {
    final entries = buildProductEntries(products);
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
    final entries = buildProductEntries(products);
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
    final products = await _future;
    if (!mounted) return;
    final qty = <int, int>{}; // total de botellines (lo que se guarda)
    final loose = <int, int>{}; // sueltos: se mezclan en el plan
    final boxes = <int, int>{}; // cajas completas: van dedicadas en el plan
    for (final p in products) {
      final b = _boxes[p.id] ?? 0;
      final l = _loose[p.id] ?? 0;
      if (b == 0 && l == 0) continue;
      qty[p.id!] = b * _boxSize(p) + l;
      if (l > 0) loose[p.id!] = l;
      if (b > 0) boxes[p.id!] = b;
    }
    if (qty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade algún botellín a la lista')));
      return;
    }
    await Db.i.saveNight(Schedule.fmt(_date), qty);
    if (!mounted) return;
    setState(() {
      _boxes.clear();
      _loose.clear();
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanScreen(qty: loose, fullBoxes: boxes),
      ),
    );
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
                        _totalFor(product) > 0)
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
