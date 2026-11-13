import 'package:flutter/material.dart';

import '../app_design.dart';
import '../auth_controller.dart';
import '../db.dart';
import '../formats.dart';
import '../models.dart';
import '../product_entries.dart';
import '../schedule.dart';
import '../shifts.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_ui.dart';
import '../widgets/category_tabs.dart';
import '../widgets/quantity_stepper.dart';
import 'confirmar_lista.dart';
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

  /// Cada noche tiene una lista independiente por planta.
  Floor _floor = Floor.plantaBaja;

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
    _loadNight(); // muestra la lista ya guardada de la fecha de servicio actual
  }

  /// Carga en el formulario la lista guardada de [_date]. Se reparte el total
  /// en cajas completas y botellines sueltos según las unidades por caja, ya
  /// que la BD solo guarda el total de botellines.
  Future<void> _loadNight() async {
    final date = _date;
    final floor = _floor;
    try {
      final products = await _future;
      final saved = await Db.i.nightConsumption(Schedule.fmt(date), floor);
      // Si mientras cargaba cambió la fecha o la planta, no se pisa la nueva
      // selección.
      if (!mounted || date != _date || floor != _floor) return;
      final boxes = <int, int>{};
      final loose = <int, int>{};
      for (final p in products) {
        final total = saved[p.id] ?? 0;
        if (total <= 0) continue;
        final size = _boxSize(p);
        boxes[p.id!] = total ~/ size;
        loose[p.id!] = total % size;
      }
      setState(() {
        _boxes
          ..clear()
          ..addAll(boxes);
        _loose
          ..clear()
          ..addAll(loose);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo cargar la lista guardada: '
            '${describeDbError(error)}'),
      ));
    }
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

  /// Controles de cantidad de un producto (cajas completas y sueltos).
  Widget _quantityControls(Product product, {StateSetter? refreshOverlay}) {
    final unit = _boxSize(product);
    final boxes = _boxes[product.id] ?? 0;
    final loose = _loose[product.id] ?? 0;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        if (unit > 1)
          QuantityStepper(
            label: 'Cajas',
            value: boxes,
            onDecrement: boxes > 0
                ? () => _setBoxes(product, boxes - 1,
                    refreshOverlay: refreshOverlay)
                : null,
            onIncrement: () =>
                _setBoxes(product, boxes + 1, refreshOverlay: refreshOverlay),
          ),
        QuantityStepper(
          label: unit > 1 ? 'Sueltos' : 'Unidades',
          value: loose,
          onDecrement: loose > 0
              ? () =>
                  _setLoose(product, loose - 1, refreshOverlay: refreshOverlay)
              : null,
          onIncrement: () =>
              _setLoose(product, loose + 1, refreshOverlay: refreshOverlay),
        ),
      ],
    );
  }

  /// Imagen a mostrar de un producto/variante: la suya o, si no tiene, la del
  /// grupo al que pertenece (p. ej. todas las Cruzcampo comparten marca).
  String? _productImage(Product product) {
    final own = product.image?.trim();
    if (own != null && own.isNotEmpty) return own;
    final group = product.groupImage?.trim();
    return group != null && group.isNotEmpty ? group : null;
  }

  String _boxHint(Product product) {
    final unit = _boxSize(product);
    if (unit <= 1) return 'Unidad suelta';
    return '${product.crateName} · $unit uds/caja';
  }

  /// Miniatura unificada de las filas y tarjetas.
  Widget _thumb(String? path, IconData placeholder, {double size = 48}) {
    final cleaned = path?.trim();
    final theme = Theme.of(context);
    final cacheWidth =
        (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: cleaned == null || cleaned.isEmpty
          ? Icon(
              placeholder,
              size: size * 0.52,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : Image.asset(
              cleaned,
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_outlined,
                size: size * 0.52,
                color: theme.colorScheme.error,
              ),
            ),
    );
  }

  Widget _totalBadge(int total) {
    final theme = Theme.of(context);
    final hasValue = total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: hasValue
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: hasValue
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        hasValue ? '$total uds' : 'Sin añadir',
        style: theme.textTheme.labelSmall?.copyWith(
          color: hasValue
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _productTile(
    Product product, {
    String? title,
    StateSetter? refreshOverlay,
  }) {
    final total = _totalFor(product);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final identity = Row(
          children: [
            _thumb(_productImage(product), Icons.local_drink_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _boxHint(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _totalBadge(total),
          ],
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: AppSpacing.md),
                _quantityControls(product, refreshOverlay: refreshOverlay),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.lg),
              _quantityControls(product, refreshOverlay: refreshOverlay),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseVariants(ProductEntry entry) async {
    final variants = entry.products;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshOverlay) {
          final screen = MediaQuery.sizeOf(context);
          final height = screen.width < AppBreakpoints.mobileMax
              ? screen.height * 0.82
              : screen.height * 0.72;
          return SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.groupName!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${variants.length} variantes · ajusta cajas y sueltos',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    itemCount: variants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      return _productTile(
                        variant,
                        title: ProductEntry.label(variant),
                        refreshOverlay: refreshOverlay,
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Listo'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _groupListTile(ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + _totalFor(product),
    );
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _chooseVariants(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _thumb(entry.image, Icons.inventory_2_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.groupName!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${entry.products.length} variantes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (count > 0) _totalBadge(count),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Imagen de una tarjeta de cuadrícula, con placeholder si no hay archivo.
  Widget _gridThumb(String? path, IconData placeholder) {
    final theme = Theme.of(context);
    final cleaned = path?.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decodifica el asset al ancho real de la celda en vez de a su tamaño
        // original (hay PNG de más de 1700 px para una tarjeta de ~150 px).
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 200;
        final cacheWidth =
            (width * MediaQuery.devicePixelRatioOf(context)).round();
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: cleaned == null || cleaned.isEmpty
              ? Icon(
                  placeholder,
                  size: 38,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : Image.asset(
                  cleaned,
                  fit: BoxFit.contain,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    size: 38,
                    color: theme.colorScheme.error,
                  ),
                ),
        );
      },
    );
  }

  Widget _groupGridCard(ProductEntry entry) {
    final count = entry.products.fold<int>(
      0,
      (total, product) => total + _totalFor(product),
    );
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _chooseVariants(entry),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _gridThumb(entry.image, Icons.inventory_2_outlined),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                entry.groupName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.products.length} variantes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (count > 0) _totalBadge(count),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productGridCard(Product product) {
    final total = _totalFor(product);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editQuantity(product),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _gridThumb(
                  _productImage(product),
                  Icons.local_drink_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _boxHint(product),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _totalBadge(total),
                ],
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
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshOverlay) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _thumb(
                    _productImage(product),
                    Icons.local_drink_outlined,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _boxHint(product),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              _quantityControls(product, refreshOverlay: refreshOverlay),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryList(List<Product> products) {
    final entries = buildProductEntries(products);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return entry.isGroup
            ? _groupListTile(entry)
            : _productTile(entry.products.single);
      },
    );
  }

  Widget _categoryGrid(List<Product> products) {
    final entries = buildProductEntries(products);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppBreakpoints.gridColumns(
          constraints.maxWidth,
          min: 2,
          max: 5,
          minTileWidth: 150,
        );
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 200,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return entry.isGroup
                ? _groupGridCard(entry)
                : _productGridCard(entry.products.single);
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: Schedule.retentionLimit(),
        lastDate: DateTime.now());
    if (d == null || d == _date) return;
    setState(() {
      _date = d;
      // Se limpia lo escrito y se muestra lo guardado de la nueva fecha.
      _boxes.clear();
      _loose.clear();
    });
    await _loadNight();
  }

  Future<void> _pickFloor(Floor floor) async {
    if (floor == _floor) return;
    setState(() {
      _floor = floor;
      // Se limpia lo escrito y se muestra lo guardado de la nueva planta.
      _boxes.clear();
      _loose.clear();
    });
    await _loadNight();
  }

  Future<void> _save() async {
    final products = await _future;
    if (!mounted) return;
    final qty = <int, int>{}; // total de botellines (lo que se guarda)
    final loose = <int, int>{}; // sueltos: se mezclan en el plan
    final boxes = <int, int>{}; // cajas completas: van dedicadas en el plan
    final lines = <LineaPedido>[]; // resumen que se pide confirmar
    for (final p in products) {
      final b = _boxes[p.id] ?? 0;
      final l = _loose[p.id] ?? 0;
      if (b == 0 && l == 0) continue;
      qty[p.id!] = b * _boxSize(p) + l;
      if (l > 0) loose[p.id!] = l;
      if (b > 0) boxes[p.id!] = b;
      lines.add(LineaPedido(p, boxes: b, loose: l));
    }
    if (qty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade algún botellín a la lista')));
      return;
    }
    // Pantalla intermedia: se revisa el resumen y se confirma antes de guardar.
    final date = _date;
    final floor = _floor;
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConfirmarListaScreen(date: date, floor: floor, lines: lines),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Db.i.saveNight(Schedule.fmt(date), floor, qty);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo guardar la lista: '
            '${describeDbError(error)}'),
      ));
      return;
    }
    if (!mounted) return;
    // Mantenimiento sigue el estado de la lista desde su Inicio; el resto de
    // usuarios recibe aquí la confirmación de que se guardó correctamente.
    if (AuthController.i.user?.isMaintenance != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lista guardada correctamente.')),
      );
    }
    // Refleja exactamente lo guardado (el total repartido en cajas y sueltos).
    await _loadNight();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanScreen(
          qty: loose,
          fullBoxes: boxes,
          title: 'Montar cajas',
          date: Schedule.fmt(date),
          floor: floor,
        ),
      ),
    );
  }

  Widget _header() {
    // Controles compactos: fecha, planta y modo de visualización.
    // En móvil cada control es una tarjeta con el icono encima y el dato
    // debajo, para que quepan en una sola fila; en tablet y escritorio se
    // mantienen los controles anchos de siempre.
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMax;

    final controlDecoration = BoxDecoration(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    );

    final dateControl = compact
        ? _compactTile(
            tooltip: 'Cambiar fecha del servicio',
            onTap: _pickDate,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatWeekdayShort(_date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  formatDayMonth(_date),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        : Tooltip(
            message: 'Cambiar fecha del servicio',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: _pickDate,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: controlDecoration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 17, color: theme.colorScheme.primary),
                      const SizedBox(width: 7),
                      Text(
                        formatShortDate(_date),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          );

    // Desplegable de planta: la lista guardada se consulta por separado para
    // planta baja, karaoke y terraza.
    final floorControl = compact
        ? _compactTile(
            tooltip: 'Cambiar la planta de la lista',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<Floor>(
                    value: _floor,
                    isDense: true,
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    icon: const Icon(Icons.expand_more, size: 12),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                    selectedItemBuilder: (context) => [
                      for (final floor in Floor.values)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(floor.short),
                        ),
                    ],
                    items: [
                      for (final floor in Floor.values)
                        DropdownMenuItem(
                          value: floor,
                          child: Text(
                            floor.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _pickFloor(value);
                    },
                  ),
                ),
              ],
            ),
          )
        : Tooltip(
            message: 'Cambiar la planta de la lista',
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: controlDecoration,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Floor>(
                      value: _floor,
                      isDense: true,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      icon: const Icon(Icons.expand_more, size: 18),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      selectedItemBuilder: (context) => [
                        for (final floor in Floor.values)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Planta: ${floor.label}'),
                          ),
                      ],
                      items: [
                        for (final floor in Floor.values)
                          DropdownMenuItem(
                            value: floor,
                            child: Text(floor.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _pickFloor(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );

    final viewControl = compact
        ? _compactTile(
            width: 44,
            tooltip: _gridView ? 'Ver en lista' : 'Ver en cuadrícula',
            onTap: () => setState(() => _gridView = !_gridView),
            child: Center(
              child: Icon(
                _gridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: controlDecoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewModeButton(
                  icon: Icons.view_list_rounded,
                  selected: !_gridView,
                  tooltip: 'Ver en lista',
                  onTap: () => setState(() => _gridView = false),
                ),
                _viewModeButton(
                  icon: Icons.grid_view_rounded,
                  selected: _gridView,
                  tooltip: 'Ver en cuadrícula',
                  onTap: () => setState(() => _gridView = true),
                ),
              ],
            ),
          );

    return AppPageHeader(
      eyebrow: 'Operación nocturna',
      title: 'Lista de montaje',
      leading: const AppLogo(height: 24),
      compact: true,
      // En móvil los controles van dentro de la cabecera, a la altura del
      // título, en vez de ocupar una fila completa debajo.
      inlineActions: compact,
      actions: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [dateControl, floorControl, viewControl],
        ),
      ],
    );
  }

  /// Tarjeta compacta de la cabecera en móvil: 44 px de alto y ancho según su
  /// contenido, con el icono y el dato apilados en dos líneas.
  Widget _compactTile({
    required String tooltip,
    required Widget child,
    VoidCallback? onTap,
    double? width,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadii.md);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: width,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _viewModeButton({
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: SizedBox(
            width: 34,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  ({int products, int boxes, int units}) _summary(List<Product> products) {
    var selected = 0;
    var boxes = 0;
    var units = 0;
    for (final product in products) {
      final productBoxes = _boxes[product.id] ?? 0;
      final loose = _loose[product.id] ?? 0;
      if (productBoxes == 0 && loose == 0) continue;
      selected++;
      boxes += productBoxes;
      units += productBoxes * _boxSize(product) + loose;
    }
    return (products: selected, boxes: boxes, units: units);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final contentWidth =
            pageConstraints.maxWidth > AppBreakpoints.contentMaxWidth
                ? AppBreakpoints.contentMaxWidth
                : pageConstraints.maxWidth;
        return FutureBuilder<List<Product>>(
          future: _future,
          builder: (_, snapshot) {
            final products = snapshot.data;
            final summary = products == null
                ? (products: 0, boxes: 0, units: 0)
                : _summary(products);
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              pageConstraints.maxWidth >=
                                      AppBreakpoints.tabletMin
                                  ? AppSpacing.xl
                                  : AppSpacing.lg,
                              pageConstraints.maxWidth >=
                                      AppBreakpoints.tabletMin
                                  ? AppSpacing.md
                                  : AppSpacing.sm,
                              pageConstraints.maxWidth >=
                                      AppBreakpoints.tabletMin
                                  ? AppSpacing.xl
                                  : AppSpacing.lg,
                              pageConstraints.maxWidth >=
                                      AppBreakpoints.tabletMin
                                  ? AppSpacing.md
                                  : AppSpacing.sm,
                            ),
                            child: _header(),
                          ),
                          Expanded(
                            child: _content(snapshot),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (products != null && products.isNotEmpty)
                  _MontajeActionBar(
                    contentWidth: contentWidth,
                    products: summary.products,
                    boxes: summary.boxes,
                    units: summary.units,
                    onSave: _save,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _content(AsyncSnapshot<List<Product>> snapshot) {
    if (snapshot.hasError) {
      return AppErrorState(
        title: 'No se pudieron cargar los productos.',
        error: snapshot.error!,
        onRetry: _reload,
      );
    }
    if (!snapshot.hasData) {
      return const AppLoadingState(label: 'Cargando el catálogo…');
    }
    if (snapshot.data!.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No hay productos en el catálogo',
        message: 'Añade productos desde Admin → Productos para empezar a '
            'preparar la lista de montaje.',
      );
    }
    final products = snapshot.data!;
    return CategoryTabs(
      products: products,
      badge: (category) {
        final count = products
            .where((product) =>
                product.category == category && _totalFor(product) > 0)
            .length;
        return count == 0 ? '' : ' ($count)';
      },
      builder: (_, categoryProducts) => _gridView
          ? _categoryGrid(categoryProducts)
          : _categoryList(categoryProducts),
    );
  }
}

/// Barra fija de montaje: resume el pedido y mantiene la acción principal
/// accesible sin tapar el contenido ni la navegación inferior.
class _MontajeActionBar extends StatelessWidget {
  final double contentWidth;
  final int products;
  final int boxes;
  final int units;
  final VoidCallback onSave;

  const _MontajeActionBar({
    required this.contentWidth,
    required this.products,
    required this.boxes,
    required this.units,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        _SummaryMetric(label: 'Productos', value: '$products'),
        _SummaryMetric(label: 'Cajas', value: '$boxes'),
        _SummaryMetric(label: 'Unidades', value: '$units'),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final button = FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.inventory_2_outlined, size: 19),
                  label: const Text('Guardar y montar cajas'),
                );
                if (constraints.maxWidth < 580) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: summary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(width: double.infinity, child: button),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: AppSpacing.lg),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label.toLowerCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
