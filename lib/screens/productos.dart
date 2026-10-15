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
  double? _d(String s) => double.tryParse(s.replaceAll(',', '.'));

  /// Alta (p == null) o edición de un producto.
  Future<void> _edit([Product? p]) async {
    final existingGroupImage = p?.groupName?.trim().isNotEmpty ?? false
        ? await Db.i.productGroupImage(
            category: p!.category,
            name: p.groupName!,
          )
        : null;
    if (!mounted) return;

    final name = TextEditingController(text: p?.name ?? '');
    final cat = TextEditingController(
        text: p?.category ?? _cat ?? 'Cervezas y similares');
    final group = TextEditingController(text: p?.groupName ?? '');
    final subcategory = TextEditingController(text: p?.subcategory ?? '');
    final image = TextEditingController(text: p?.image ?? '');
    final groupImage = TextEditingController(text: existingGroupImage ?? '');
    final units = TextEditingController(text: '${p?.unitsPerBox ?? 24}');
    final size = TextEditingController(text: _n(p?.size ?? 1));
    final height = TextEditingController(text: _n(p?.height ?? 1));
    final format = TextEditingController(text: '${p?.format ?? 1}');
    final crate = TextEditingController(text: p?.crateName ?? '');
    final trip = TextEditingController(text: '${p?.tripCapacity ?? 5}');
    const decimal = TextInputType.numberWithOptions(decimal: true);

    final controllers = [
      name,
      cat,
      group,
      subcategory,
      image,
      groupImage,
      units,
      size,
      height,
      format,
      crate,
      trip,
    ];
    try {
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
                  controller: group,
                  decoration:
                      const InputDecoration(labelText: 'Grupo de variantes')),
              TextField(
                  controller: subcategory,
                  decoration: const InputDecoration(labelText: 'Subcategoría')),
              TextField(
                  controller: image,
                  decoration:
                      const InputDecoration(labelText: 'Imagen del producto (ruta o URI)')),
              TextField(
                  controller: groupImage,
                  decoration: const InputDecoration(
                      labelText: 'Imagen general del grupo (ruta o URI)')),
              TextField(
                  controller: units,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Unidades por caja')),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: size,
                        keyboardType: decimal,
                        decoration:
                            const InputDecoration(labelText: 'Tamaño'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: height,
                        keyboardType: decimal,
                        decoration:
                            const InputDecoration(labelText: 'Altura'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: format,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Formato'))),
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
      if (!mounted || ok != true) return;

      final unitsPerBox = int.tryParse(units.text);
      final productSize = _d(size.text);
      final productHeight = _d(height.text);
      final productFormat = int.tryParse(format.text);
      final tripCapacity = int.tryParse(trip.text);
      if (unitsPerBox == null ||
          productSize == null ||
          productHeight == null ||
          productFormat == null ||
          tripCapacity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisa los valores numéricos.')),
        );
        return;
      }

      final np = Product(
        id: p?.id,
        name: name.text.trim(),
        category: cat.text.trim().isEmpty ? 'Otros' : cat.text.trim(),
        groupName: group.text.trim().isEmpty ? null : group.text.trim(),
        subcategory:
            subcategory.text.trim().isEmpty ? null : subcategory.text.trim(),
        image: image.text.trim().isEmpty ? null : image.text.trim(),
        unitsPerBox: unitsPerBox,
        size: productSize,
        height: productHeight,
        format: productFormat,
        crateName: crate.text.trim(),
        tripCapacity: tripCapacity,
      );
      final validationError = np.validationError;
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
        return;
      }
      final groupName = np.groupName?.trim();
      final groupImagePath =
          groupName == null || groupName.isEmpty || groupImage.text.trim().isEmpty
              ? null
              : groupImage.text.trim();
      p == null
          ? await Db.i.addProduct(np, groupImage: groupImagePath)
          : await Db.i.updateProduct(np, groupImage: groupImagePath);
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
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
    if (!mounted) return;
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
            if (s.hasError) {
              return Center(
                child: Text('No se pudieron cargar los productos: ${s.error}'),
              );
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.isEmpty) {
              return const Center(
                  child: Text('Añade tu primer producto con +'));
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
