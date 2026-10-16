import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets/category_tabs.dart';

/// Datos que devuelve el formulario de alta/edición de un producto.
typedef _ProductForm = ({Product product, String? groupImage});

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

  /// Alta (p == null) o edición de un producto.
  Future<void> _edit([Product? p]) async {
    final existingGroupImage = p?.groupName?.trim().isNotEmpty ?? false
        ? await Db.i.productGroupImage(
            category: p!.category,
            name: p.groupName!,
          )
        : null;
    if (!mounted) return;

    // El formulario gestiona sus propios controllers: se crean y se destruyen
    // dentro del diálogo, no aquí, para no destruirlos mientras sus TextField
    // siguen montados (provocaba la aserción '_dependents.isEmpty').
    final form = await showDialog<_ProductForm>(
      context: context,
      builder: (_) => _ProductDialog(
        product: p,
        defaultCategory: _cat ?? 'Cervezas y similares',
        existingGroupImage: existingGroupImage,
      ),
    );
    if (!mounted || form == null) return;

    if (p == null) {
      await Db.i.addProduct(form.product, groupImage: form.groupImage);
    } else {
      await Db.i.updateProduct(form.product, groupImage: form.groupImage);
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

/// Formulario de alta/edición. Es dueño de sus [TextEditingController], que
/// se destruyen en [dispose] (cuando el diálogo ya se ha desmontado).
class _ProductDialog extends StatefulWidget {
  final Product? product;
  final String defaultCategory;
  final String? existingGroupImage;

  const _ProductDialog({
    required this.product,
    required this.defaultCategory,
    required this.existingGroupImage,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  static const _decimal = TextInputType.numberWithOptions(decimal: true);

  late final TextEditingController name;
  late final TextEditingController cat;
  late final TextEditingController group;
  late final TextEditingController subcategory;
  late final TextEditingController image;
  late final TextEditingController groupImage;
  late final TextEditingController units;
  late final TextEditingController size;
  late final TextEditingController height;
  late final TextEditingController format;
  late final TextEditingController crate;
  late final TextEditingController trip;
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    cat = TextEditingController(text: p?.category ?? widget.defaultCategory);
    group = TextEditingController(text: p?.groupName ?? '');
    subcategory = TextEditingController(text: p?.subcategory ?? '');
    image = TextEditingController(text: p?.image ?? '');
    groupImage = TextEditingController(text: widget.existingGroupImage ?? '');
    units = TextEditingController(text: '${p?.unitsPerBox ?? 24}');
    size = TextEditingController(text: _n(p?.size ?? 1));
    height = TextEditingController(text: _n(p?.height ?? 1));
    format = TextEditingController(text: '${p?.format ?? 1}');
    crate = TextEditingController(text: p?.crateName ?? '');
    trip = TextEditingController(text: '${p?.tripCapacity ?? 5}');
    _controllers = [
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
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  double? _d(String s) => double.tryParse(s.replaceAll(',', '.'));

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _save() {
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
      _showError('Revisa los valores numéricos.');
      return;
    }

    final product = Product(
      id: widget.product?.id,
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

    final validationError = product.validationError;
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final groupName = product.groupName?.trim();
    final groupImagePath = groupName == null ||
            groupName.isEmpty ||
            groupImage.text.trim().isEmpty
        ? null
        : groupImage.text.trim();

    Navigator.pop(context, (product: product, groupImage: groupImagePath));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
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
                decoration: const InputDecoration(
                    labelText: 'Imagen del producto (ruta o URI)')),
            TextField(
                controller: groupImage,
                decoration: const InputDecoration(
                    labelText: 'Imagen general del grupo (ruta o URI)')),
            TextField(
                controller: units,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unidades por caja')),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: size,
                      keyboardType: _decimal,
                      decoration: const InputDecoration(labelText: 'Tamaño'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: height,
                      keyboardType: _decimal,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      );
}
