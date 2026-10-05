import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets/category_tabs.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});
  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  late Future<List<Product>> _future = Db.i.products();
  String? _cat; // pestaña visible

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

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  double _d(String s, double fallback) =>
      double.tryParse(s.replaceAll(',', '.')) ?? fallback;

  /// Alta (p == null) o edición de un producto.
  Future<void> _edit([Product? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final cat = TextEditingController(
        text: p?.category ?? _cat ?? 'Cervezas y similares');
    final units = TextEditingController(text: '${p?.unitsPerBox ?? 24}');
    final size = TextEditingController(text: _n(p?.size ?? 1));
    final height = TextEditingController(text: _n(p?.height ?? 1));
    final format = TextEditingController(text: '${p?.format ?? 1}');
    final crate = TextEditingController(text: p?.crateName ?? '');
    final trip = TextEditingController(text: '${p?.tripCapacity ?? 5}');
    const decimal = TextInputType.numberWithOptions(decimal: true);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
                controller: cat,
                decoration: const InputDecoration(labelText: 'Categoría')),
            TextField(
                controller: units,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unidades por caja')),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: size,
                      keyboardType: decimal,
                      decoration: const InputDecoration(labelText: 'Tamaño'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: height,
                      keyboardType: decimal,
                      decoration: const InputDecoration(labelText: 'Altura'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: format,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Formato'))),
            ]),
            TextField(
                controller: crate,
                decoration: const InputDecoration(
                    labelText: 'Tipo de caja (Cerveza, Cola…)')),
            TextField(
                controller: trip,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Cajas de este tipo por viaje')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final np = Product(
      id: p?.id,
      name: name.text.trim(),
      category: cat.text.trim().isEmpty ? 'Otros' : cat.text.trim(),
      unitsPerBox: int.tryParse(units.text) ?? 24,
      size: _d(size.text, 1),
      height: _d(height.text, 1),
      format: int.tryParse(format.text) ?? 1,
      crateName: crate.text.trim(),
      tripCapacity: int.tryParse(trip.text) ?? 5,
    );
    p == null ? await Db.i.addProduct(np) : await Db.i.updateProduct(np);
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Borrar ${p.name}?'),
        content: const Text('También se borra su histórico de consumo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) await Db.i.deleteProduct(p.id!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Productos')),
        floatingActionButton: FloatingActionButton(
            onPressed: () => _edit(), child: const Icon(Icons.add)),
        body: FutureBuilder<List<Product>>(
          future: _future,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) {
              return const Center(child: Text('Añade tu primer producto con +'));
            }
            return CategoryTabs(
              products: s.data!,
              onCategory: (c) => _cat = c,
              builder: (_, list) => ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: list
                    .map((p) => ListTile(
                          title: Text(p.name),
                          subtitle: Text(p.boxInfo),
                          onTap: () => _edit(p),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(p)),
                        ))
                    .toList(),
              ),
            );
          },
        ),
      );
}
