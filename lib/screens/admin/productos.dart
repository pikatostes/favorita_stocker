import 'package:flutter/material.dart';
import '../../db.dart';
import '../../models.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/product_catalog.dart';

/// Datos que devuelve el formulario de alta/edición de un producto.
typedef _ProductForm = ({Product product, String? groupImage});

/// Valores que existen en la BD para los desplegables del formulario.
class _ProductOptions {
  final List<String> categories;
  final Map<String, List<String>> _groups; // categoría -> grupos
  final Map<String, List<String>>
      _subcategories; // 'categoría\u0000grupo' -> subs
  final List<CrateType> boxes;
  final Map<String, CrateType> boxByName;

  const _ProductOptions({
    required this.categories,
    required Map<String, List<String>> groups,
    required Map<String, List<String>> subcategories,
    required this.boxes,
    required this.boxByName,
  })  : _groups = groups,
        _subcategories = subcategories;

  List<String> groupsFor(String category) => _groups[category] ?? const [];
  List<String> subcategoriesFor(String category, String group) =>
      _subcategories['$category\u0000$group'] ?? const [];
  CrateType? boxFor(String type) => boxByName[type];
}

/// Reúne de la BD los valores disponibles para los desplegables. Incluye
/// siempre los valores del producto que se está editando, para no perderlos.
Future<_ProductOptions> _loadOptions(Product? current) async {
  // Las cuatro consultas son independientes: se lanzan a la vez.
  final categoriesF = Db.i.categories();
  final groupsF = Db.i.productGroups();
  final subcategoriesF = Db.i.subcategories();
  final boxesF = Db.i.boxTypes();

  final categories = {...await categoriesF};
  final groups = <String, Set<String>>{};
  for (final g in await groupsF) {
    groups.putIfAbsent(g.category.trim(), () => <String>{}).add(g.name.trim());
  }
  final subcategories = <String, Set<String>>{};
  for (final s in await subcategoriesF) {
    subcategories
        .putIfAbsent(
            '${s.category.trim()}\u0000${s.group.trim()}', () => <String>{})
        .add(s.name.trim());
  }
  final boxes = <String, CrateType>{
    for (final b in await boxesF) b.name: b,
  };

  if (current != null) {
    final category = current.category.trim();
    categories.add(category);
    final group = current.groupName?.trim() ?? '';
    if (group.isNotEmpty) {
      groups.putIfAbsent(category, () => <String>{}).add(group);
    }
    final subcategory = current.subcategory?.trim() ?? '';
    if (group.isNotEmpty && subcategory.isNotEmpty) {
      subcategories
          .putIfAbsent('$category\u0000$group', () => <String>{})
          .add(subcategory);
    }
    boxes.putIfAbsent(current.box.name, () => current.box);
  }

  return _ProductOptions(
    categories: (categories.where((c) => c.isNotEmpty).toList()..sort()),
    groups: {
      for (final e in groups.entries)
        e.key: (e.value.where((g) => g.isNotEmpty).toList()..sort()),
    },
    subcategories: {
      for (final e in subcategories.entries)
        e.key: (e.value.where((s) => s.isNotEmpty).toList()..sort()),
    },
    boxes: boxes.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    boxByName: boxes,
  );
}

class ProductosScreen extends StatefulWidget {
  /// Cuando se muestra dentro de [AdminScreen] no crea AppBar propia; el botón
  /// de paletas pasa a la cabecera del contenido.
  final bool embedded;

  const ProductosScreen({super.key, this.embedded = false});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  String? _cat; // categoría visible, para el alta de productos

  /// Alta (p == null) o edición de un producto.
  Future<void> _edit([Product? p]) async {
    // La imagen del grupo y las opciones de los desplegables son consultas
    // independientes: se lanzan a la vez.
    final hasGroup = p?.groupName?.trim().isNotEmpty ?? false;
    final groupImageF = hasGroup
        ? Db.i.productGroupImage(category: p!.category, name: p.groupName!)
        : Future<String?>.value(null);
    final optionsF = _loadOptions(p);
    final existingGroupImage = await groupImageF;
    final options = await optionsF;
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
      try {
        await Db.i.addProduct(form.product, groupImage: form.groupImage);
      } catch (error) {
        if (!mounted) return;
        showAppSnack(context,
            'No se pudo guardar el producto: ${describeDbError(error)}');
      }
    } else {
      try {
        await Db.i.updateProduct(form.product, groupImage: form.groupImage);
      } catch (error) {
        if (!mounted) return;
        showAppSnack(context,
            'No se pudo guardar el producto: ${describeDbError(error)}');
      }
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showConfirmDialog(
      context,
      title: '¿Borrar ${p.name}?',
      message:
          'Dejará de aparecer en las listas, pero se conserva su histórico.',
      confirmLabel: 'Borrar',
    );
    if (!mounted) return;
    if (ok) {
      try {
        await Db.i.deleteProduct(p.id!);
      } catch (error) {
        if (!mounted) return;
        showAppSnack(context,
            'No se pudo borrar el producto: ${describeDbError(error)}');
      }
    }
  }

  Widget _body(BuildContext context) => ProductCatalog(
        emptyMessage: 'Añade tu primer producto con +',
        onCategoryChanged: (category) => _cat = category,
        onProductTap: (product) => _edit(product),
        productSubtitle: (product) => product.boxInfo,
        listPadding: const EdgeInsets.only(bottom: 90),
        trailingBuilder: (rowContext, product, inOverlay) => IconButton(
          tooltip: 'Borrar ${product.name}',
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            if (inOverlay) Navigator.of(rowContext).pop();
            _delete(product);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const AppLogo()),
        floatingActionButton: FloatingActionButton(
            onPressed: () => _edit(), child: const Icon(Icons.add)),
        body: _body(context),
      );
}

/// Formulario de alta/edición. Es dueño de sus [TextEditingController], que
/// se destruyen en [dispose] (cuando el diálogo ya se ha desmontado).
///
/// Categoría, grupo, subcategoría y tipo de caja se eligen entre los valores
/// existentes en la BD. Los botones «+» de grupo y subcategoría permiten crear
/// valores nuevos sin salir del formulario. Los números describen la caja
/// seleccionada, que es compartida por todos los productos de ese tipo.
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
  late final TextEditingController width;
  late final TextEditingController format;
  late final TextEditingController trip;
  late final List<TextEditingController> _controllers;

  late String _category;
  String? _group;
  String? _subcategory;
  late String _boxType;
  bool _isBottle = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    image = TextEditingController(text: p?.image ?? '');
    groupImage = TextEditingController(text: widget.existingGroupImage ?? '');
    units = TextEditingController();
    size = TextEditingController();
    height = TextEditingController();
    width = TextEditingController();
    format = TextEditingController();
    trip = TextEditingController();
    _controllers = [
      name,
      image,
      groupImage,
      units,
      size,
      height,
      width,
      format,
      trip,
    ];

    // Categoría: el producto, la pestaña visible, o la primera disponible.
    final cat = p?.category.trim();
    final fallback = widget.defaultCategory?.trim();
    final cats = widget.options.categories;
    if (cat != null && cats.contains(cat)) {
      _category = cat;
    } else if (fallback != null && cats.contains(fallback)) {
      _category = fallback;
    } else {
      _category = cats.isNotEmpty ? cats.first : '';
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
            widget.options
                .subcategoriesFor(_category, _group!)
                .contains(subcategory))
        ? subcategory
        : null;

    final boxName = p?.box.name.trim() ?? '';
    final boxes = widget.options.boxes;
    _boxType =
        (boxName.isNotEmpty && widget.options.boxByName.containsKey(boxName))
            ? boxName
            : (boxes.isNotEmpty ? boxes.first.name : '');
    // «Alcohol» siempre se cuenta con la caja de botellas.
    final bottle = _bottleBox;
    if (_isAlcohol && bottle != null) _boxType = bottle.name;
    _fillBox(widget.options.boxFor(_boxType) ?? p?.box);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _n(double v) => formatMeasure(v);
  double? _d(String s) => double.tryParse(s.replaceAll(',', '.'));

  /// Copia en los campos numéricos los atributos del tipo de caja dado.
  void _fillBox(CrateType? b) {
    _isBottle = b?.isBottle ?? false;
    units.text = '${b?.units ?? 24}';
    size.text = _n(b?.size ?? 1);
    height.text = _n(b?.height ?? 1);
    width.text = _n(b?.width ?? 1);
    format.text = '${b?.format ?? 1}';
    trip.text = '${b?.trip ?? 5}';
  }

  /// Tipo de caja de las botellas («Botella»), si existe en el catálogo.
  CrateType? get _bottleBox {
    for (final box in widget.options.boxes) {
      if (box.isBottle) return box;
    }
    return widget.options.boxByName['Botella'];
  }

  /// La categoría «Alcohol» obliga a usar la caja de botellas.
  bool get _isAlcohol => _category.trim().toLowerCase() == 'alcohol';

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _save() {
    final unitsPerBox = int.tryParse(units.text);
    final productSize = _d(size.text);
    final productHeight = _d(height.text);
    final productWidth = _d(width.text);
    final productFormat = int.tryParse(format.text);
    final tripCapacity = int.tryParse(trip.text);
    if (unitsPerBox == null ||
        productSize == null ||
        productHeight == null ||
        productWidth == null ||
        productFormat == null ||
        tripCapacity == null) {
      _showError('Revisa los valores numéricos.');
      return;
    }

    final box = CrateType(
      _boxType.trim().isEmpty ? 'Caja' : _boxType.trim(),
      unitsPerBox,
      productSize,
      productHeight,
      productFormat,
      tripCapacity,
      width: productWidth,
      isBottle: _isBottle,
    );
    final product = Product(
      id: widget.product?.id,
      name: name.text.trim(),
      category: _category.trim().isEmpty ? 'Otros' : _category.trim(),
      groupName: _group,
      subcategory: _subcategory,
      image: image.text.trim().isEmpty ? null : image.text.trim(),
      box: box,
      unitInStock: widget.product?.unitInStock ?? 0,
      unitInTerraceStock: widget.product?.unitInTerraceStock ?? 0,
    );

    final validationError = product.validationError;
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final groupName = product.groupName?.trim();
    final groupImagePath =
        groupName == null || groupName.isEmpty || groupImage.text.trim().isEmpty
            ? null
            : groupImage.text.trim();

    Navigator.pop(context, (product: product, groupImage: groupImagePath));
  }

  /// Pide un nombre nuevo (grupo o subcategoría) y lo deja seleccionado. El
  /// valor se crea en la BD al guardar el producto, porque `save_product` hace
  /// upsert del grupo y de la subcategoría.
  Future<void> _addName({
    required String title,
    required String label,
    required ValueChanged<String> onSaved,
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, label: label),
    );
    final value = name?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    onSaved(value);
  }

  @override
  Widget build(BuildContext context) {
    // Se incluye el valor elegido aunque todavía no exista en la BD: al pulsar
    // «+» se puede crear un grupo o una subcategoría nueva y se guarda al
    // aceptar.
    final groups = <String>[...widget.options.groupsFor(_category)];
    if (_group != null && !groups.contains(_group)) groups.add(_group!);
    final subcategories = _group == null
        ? <String>[]
        : <String>[...widget.options.subcategoriesFor(_category, _group!)];
    if (_subcategory != null && !subcategories.contains(_subcategory)) {
      subcategories.add(_subcategory!);
    }

    return AlertDialog(
      title:
          Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
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
                    value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v == null) return;
              final bottle = _bottleBox;
              setState(() {
                _category = v;
                _group = null;
                _subcategory = null;
                if (_isAlcohol) {
                  // Categoría Alcohol: caja de botellas fija.
                  if (bottle != null) {
                    _boxType = bottle.name;
                    _fillBox(bottle);
                  }
                } else if (_isBottle) {
                  // Al salir de Alcohol no se queda con la caja de botella.
                  final other =
                      widget.options.boxes.where((box) => !box.isBottle);
                  if (other.isNotEmpty) {
                    _boxType = other.first.name;
                    _fillBox(other.first);
                  }
                }
              });
            },
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _group,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Grupo de variantes'),
                  items: [
                    for (final g in groups)
                      DropdownMenuItem<String>(
                          value: g,
                          child: Text(g, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: groups.isEmpty
                      ? null
                      : (v) => setState(() {
                            _group = v;
                            _subcategory = null;
                          }),
                ),
              ),
              IconButton(
                tooltip: 'Añadir un grupo',
                icon: const Icon(Icons.add),
                onPressed: () => _addName(
                  title: 'Nuevo grupo de variantes',
                  label: 'Nombre del grupo',
                  onSaved: (name) => setState(() {
                    _group = name;
                    _subcategory = null;
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _subcategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Subcategoría (opcional)'),
                  items: [
                    for (final s in subcategories)
                      DropdownMenuItem<String>(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _group == null || subcategories.isEmpty
                      ? null
                      : (v) => setState(() => _subcategory = v),
                ),
              ),
              IconButton(
                tooltip: 'Añadir una subcategoría',
                icon: const Icon(Icons.add),
                onPressed: _group == null
                    ? null
                    : () => _addName(
                          title: 'Nueva subcategoría',
                          label: 'Nombre de la subcategoría',
                          onSaved: (name) =>
                              setState(() => _subcategory = name),
                        ),
              ),
            ],
          ),
          TextField(
              controller: image,
              decoration: const InputDecoration(
                  labelText: 'Imagen del producto (ruta o URI)')),
          TextField(
              controller: groupImage,
              decoration: const InputDecoration(
                  labelText: 'Imagen general del grupo (ruta o URI)')),
          DropdownButtonFormField<String>(
            initialValue: _boxType.isEmpty ? null : _boxType,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Tipo de caja (Cerveza, Cola…)'),
            items: [
              for (final b in widget.options.boxes)
                DropdownMenuItem<String>(
                    value: b.name,
                    child: Text(b.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _isAlcohol
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _boxType = v;
                      _fillBox(widget.options.boxFor(v));
                    });
                  },
          ),
          if (_isBottle)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Se cuenta por botellas y no entra en el montaje ni en la '
                'previsión. Categoría «Alcohol», grupo = tipo (Ron, Whisky…) '
                'y subcategoría = marca (Barceló, Brugal…).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          TextField(
              controller: units,
              enabled: !_isBottle,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Unidades por caja')),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: size,
                    enabled: !_isBottle,
                    keyboardType: _decimal,
                    decoration: const InputDecoration(labelText: 'Tamaño'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: height,
                    enabled: !_isBottle,
                    keyboardType: _decimal,
                    decoration: const InputDecoration(labelText: 'Altura'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: width,
                    enabled: !_isBottle,
                    keyboardType: _decimal,
                    decoration: const InputDecoration(labelText: 'Ancho'))),
          ]),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: format,
                    enabled: !_isBottle,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Formato'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: trip,
                    enabled: !_isBottle,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Cajas por viaje'))),
          ]),
          const SizedBox(height: 4),
          Text(
            _isBottle
                ? 'Las botellas se cuentan de una en una: el tipo de caja '
                    '«Botella» no se puede cambiar.'
                : 'Los datos de la caja se comparten entre todos los productos de ese tipo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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

/// Diálogo de una línea para crear un grupo o una subcategoría nueva sin salir
/// del formulario de producto.
class _NameDialog extends StatefulWidget {
  final String title;
  final String label;

  const _NameDialog({required this.title, required this.label});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Añadir')),
        ],
      );
}
