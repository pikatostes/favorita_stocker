import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../widgets/category_tabs.dart';

/// Datos que devuelve el formulario de alta/edición de un producto.
typedef _ProductForm = ({Product product, String? groupImage});

/// Valores que existen en la BD para los desplegables del formulario.
class _ProductOptions {
  final List<String> categories;
  final List<String> crateNames;
  final Map<String, List<String>> _groups; // categoría -> grupos
  final Map<String, List<String>> _subcategories; // 'categoría\u0000grupo' -> subs

  const _ProductOptions({
    required this.categories,
    required this.crateNames,
    required Map<String, List<String>> groups,
    required Map<String, List<String>> subcategories,
  })  : _groups = groups,
        _subcategories = subcategories;

  List<String> groupsFor(String category) => _groups[category] ?? const [];
  List<String> subcategoriesFor(String category, String group) =>
      _subcategories['$category\u0000$group'] ?? const [];
}

/// Reúne de la BD los valores disponibles para los desplegables. Incluye
/// siempre los valores del producto que se está editando, para no perderlos.
Future<_ProductOptions> _loadOptions(Product? current) async {
  final products = await Db.i.products();
  final groups = await Db.i.productGroups();

  final categories = <String>{
    for (final p in products) p.category.trim(),
    for (final g in groups) g.category.trim(),
    if (current != null) current.category.trim(),
  }..removeWhere((c) => c.isEmpty);

  final groupsByCategory = <String, Set<String>>{};
  void addGroup(String category, String? group) {
    final c = category.trim();
    final g = group?.trim() ?? '';
    if (c.isEmpty || g.isEmpty) return;
    groupsByCategory.putIfAbsent(c, () => <String>{}).add(g);
  }

  for (final g in groups) {
    addGroup(g.category, g.name);
  }
  for (final p in products) {
    addGroup(p.category, p.groupName);
  }
  if (current != null) addGroup(current.category, current.groupName);

  final subcategoriesByGroup = <String, Set<String>>{};
  void addSubcategory(String category, String? group, String? subcategory) {
    final c = category.trim();
    final g = group?.trim() ?? '';
    final s = subcategory?.trim() ?? '';
    if (c.isEmpty || g.isEmpty || s.isEmpty) return;
    subcategoriesByGroup.putIfAbsent('$c\u0000$g', () => <String>{}).add(s);
  }

  for (final p in products) {
    addSubcategory(p.category, p.groupName, p.subcategory);
  }
  if (current != null) {
    addSubcategory(current.category, current.groupName, current.subcategory);
  }

  final crateNames = <String>{
    for (final p in products)
      if (p.crateName.trim().isNotEmpty) p.crateName.trim(),
    if (current != null && current.crateName.trim().isNotEmpty)
      current.crateName.trim(),
  }.toList()
    ..sort();

  return _ProductOptions(
    categories: categories.toList()..sort(),
    crateNames: crateNames,
    groups: {
      for (final e in groupsByCategory.entries)
        e.key: e.value.toList()..sort(),
    },
    subcategories: {
      for (final e in subcategoriesByGroup.entries)
        e.key: e.value.toList()..sort(),
    },
  );
}

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
    final options = await _loadOptions(p);
    if (!mounted) return;

    // El formulario gestiona sus propios controllers: se crean y se destruyen
    // dentro del diálogo, no aquí, para no destruirlos mientras sus TextField
    // siguen montados (provocaba la aserción '_dependents.isEmpty').
    final form = await showDialog<_ProductForm>(
      context: context,
      builder: (_) => _ProductDialog(
        product: p,
        options: options,
        defaultCategory: _cat,
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
///
/// Categoría, grupo, subcategoría y tipo de caja solo pueden elegirse entre
/// los valores existentes en la BD (desplegables estrictos).
class _ProductDialog extends StatefulWidget {
  final Product? product;
  final _ProductOptions options;
  final String? defaultCategory;
  final String? existingGroupImage;

  const _ProductDialog({
    required this.product,
    required this.options,
    required this.defaultCategory,
    required this.existingGroupImage,
  });

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  static const _decimal = TextInputType.numberWithOptions(decimal: true);

  late final TextEditingController name;
  late final TextEditingController image;
  late final TextEditingController groupImage;
  late final TextEditingController units;
  late final TextEditingController size;
  late final TextEditingController height;
  late final TextEditingController format;
  late final TextEditingController trip;
  late final List<TextEditingController> _controllers;

  late String _category;
  String? _group;
  String? _subcategory;
  late String _crate;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    image = TextEditingController(text: p?.image ?? '');
    groupImage = TextEditingController(text: widget.existingGroupImage ?? '');
    units = TextEditingController(text: '${p?.unitsPerBox ?? 24}');
    size = TextEditingController(text: _n(p?.size ?? 1));
    height = TextEditingController(text: _n(p?.height ?? 1));
    format = TextEditingController(text: '${p?.format ?? 1}');
    trip = TextEditingController(text: '${p?.tripCapacity ?? 5}');
    _controllers = [name, image, groupImage, units, size, height, format, trip];

    // Categoría: el producto, la pestaña visible, o la primera disponible.
    final cat = p?.category.trim();
    final fallback = widget.defaultCategory?.trim();
    if (cat != null && widget.options.categories.contains(cat)) {
      _category = cat;
    } else if (fallback != null && widget.options.categories.contains(fallback)) {
      _category = fallback;
    } else {
      _category =
          widget.options.categories.isNotEmpty ? widget.options.categories.first : '';
    }

    final group = p?.groupName?.trim();
    _group = (group != null &&
            group.isNotEmpty &&
            widget.options.groupsFor(_category).contains(group))
        ? group
        : null;

    final subcategory = p?.subcategory?.trim();
    _subcategory = (_group != null &&
            subcategory != null &&
            subcategory.isNotEmpty &&
            widget.options.subcategoriesFor(_category, _group!).contains(subcategory))
        ? subcategory
        : null;

    _crate = p?.crateName.trim() ?? '';
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
      category: _category.trim().isEmpty ? 'Otros' : _category.trim(),
      groupName: _group,
      subcategory: _subcategory,
      image: image.text.trim().isEmpty ? null : image.text.trim(),
      unitsPerBox: unitsPerBox,
      size: productSize,
      height: productHeight,
      format: productFormat,
      crateName: _crate,
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
  Widget build(BuildContext context) {
    final groups = widget.options.groupsFor(_category);
    final subcategories = _group == null
        ? const <String>[]
        : widget.options.subcategoriesFor(_category, _group!);
    final crateItems = <String>{'', ...widget.options.crateNames}.toList()
      ..sort();

    return AlertDialog(
      title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre')),
          DropdownButtonFormField<String>(
            initialValue: _category.isEmpty ? null : _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final c in widget.options.categories)
                DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _category = v;
                _group = null;
                _subcategory = null;
              });
            },
          ),
          DropdownButtonFormField<String?>(
            initialValue: _group,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Grupo de variantes'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('— Sin grupo —')),
              for (final g in groups)
                DropdownMenuItem<String?>(
                    value: g, child: Text(g, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _group = v;
              _subcategory = null;
            }),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _subcategory,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subcategoría'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('— Sin subcategoría —')),
              for (final s in subcategories)
                DropdownMenuItem<String?>(
                    value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _group == null
                ? null
                : (v) => setState(() => _subcategory = v),
          ),
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
          DropdownButtonFormField<String>(
            initialValue: _crate,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Tipo de caja (Cerveza, Cola…)'),
            items: [
              for (final c in crateItems)
                DropdownMenuItem<String>(
                    value: c,
                    child: Text(c.isEmpty ? '— Sin tipo —' : c,
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _crate = v ?? ''),
          ),
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
}
