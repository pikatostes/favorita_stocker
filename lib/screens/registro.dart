import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
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
  final Map<int, int> _qty = {};
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

  Widget _productTile(Product product, {String? title}) {
    final quantity = _qty[product.id] ?? 0;
    return ListTile(
      title: Text(title ?? product.name),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: quantity > 0
              ? () => setState(() => _qty[product.id!] = quantity - 1)
              : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() => _qty[product.id!] = quantity + 1),
        ),
      ]),
    );
  }

  List<Widget> _categoryProducts(List<Product> products) {
    final children = <Widget>[];
    final renderedGroups = <String>{};
    String? currentCategory;

    for (final product in products) {
      if (product.category != currentCategory) {
        currentCategory = product.category;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            product.category,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ));
      }

      final group = product.groupName?.trim();
      final subcategory = product.subcategory?.trim();
      if (group == null ||
          group.isEmpty ||
          subcategory == null ||
          subcategory.isEmpty) {
        children.add(_productTile(product));
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
      children.add(ExpansionTile(
        title: Text(group),
        children: [
          for (final variant in variants)
            _productTile(variant, title: variant.subcategory),
        ],
      ));
    }
    return children;
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
              builder: (_, categoryProducts) => ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: _categoryProducts(categoryProducts),
              ),
            );
          },
        ),
      );
}
