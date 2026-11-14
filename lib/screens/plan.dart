import 'package:flutter/material.dart';
import '../app_design.dart';
import '../data/product_repository.dart';
import '../db.dart';
import '../formats.dart';
import '../models.dart';
import '../planner.dart';
import '../product_entries.dart';
import '../shifts.dart';
import '../widgets/app_ui.dart';

/// Formas de ver el montaje: por viajes y cajas, o como lista de carga con
/// casillas para ir marcando lo que ya se ha preparado.
enum _PlanView { montaje, lista }

/// Línea de la lista de carga: el producto y el total de botellines a montar
/// (sumando sus cajas completas y sus sueltos).
typedef _CheckLine = ({Product product, int units});

/// Muestra cómo montar las cajas y en cuántos viajes llevarlas.
class PlanScreen extends StatefulWidget {
  final Map<int, int> qty; // productId -> botellines
  final Map<int, int> fullBoxes; // productId -> cajas completas pedidas
  final String title;

  /// Fecha ISO de la lista (`yyyy-MM-dd`) y planta inicial. Cuando se indican,
  /// la pantalla permite consultar las listas de las otras plantas del día.
  final String? date;
  final Floor? floor;

  const PlanScreen({
    super.key,
    required this.qty,
    this.fullBoxes = const {},
    this.title = 'Montar cajas',
    this.date,
    this.floor,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _preferFull = false;
  Floor? _floor;
  _PlanView _view = _PlanView.montaje;
  final Set<int> _checked = <int>{};
  late Future<PlanData> _future = _load();

  bool get _canSwitchFloor => widget.date != null && _floor != null;

  String get _title {
    if (!_canSwitchFloor) return widget.title;
    return '${widget.title} · ${_floor!.label} · '
        '${formatShortDateIso(widget.date!)}';
  }

  Future<PlanData> _load() => ProductRepository.i.loadPlan(
        qty: widget.qty,
        fullBoxes: widget.fullBoxes,
        preferFull: _preferFull,
        date: widget.date,
        floor: _floor,
      );

  @override
  void initState() {
    super.initState();
    _floor = widget.floor;
    Db.i.version.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  void _setPreferFull(bool value) {
    if (value == _preferFull) return;
    setState(() {
      _preferFull = value;
      _future = _load();
    });
  }

  void _selectFloor(Floor floor) {
    if (floor == _floor) return;
    setState(() {
      _floor = floor;
      _checked.clear();
      _future = _load();
    });
  }

  /// Productos del plan con su total de botellines, en orden alfabético. Es la
  /// base de la vista de lista: cada producto aparece una sola vez aunque se
  /// reparta entre varias cajas o viajes.
  List<_CheckLine> _loadLines(Plan plan) {
    final totals = <int, int>{};
    final products = <int, Product>{};
    for (final crate in plan.crates) {
      for (final line in crate.lines) {
        final id = line.product.id;
        if (id == null) continue;
        products[id] = line.product;
        totals[id] = (totals[id] ?? 0) + line.qty;
      }
    }
    final lines = [
      for (final entry in totals.entries)
        (product: products[entry.key]!, units: entry.value),
    ];
    lines.sort((a, b) => ProductEntry.product(a.product)
        .sortLabel
        .compareTo(ProductEntry.product(b.product).sortLabel));
    return lines;
  }

  void _toggleLine(int? id, bool checked) {
    if (id == null) return;
    setState(() {
      if (checked) {
        _checked.add(id);
      } else {
        _checked.remove(id);
      }
    });
  }

  /// Imagen del producto o, si no tiene, la de su grupo.
  String? _productImage(Product product) {
    final own = product.image?.trim();
    if (own != null && own.isNotEmpty) return own;
    final group = product.groupImage?.trim();
    return group != null && group.isNotEmpty ? group : null;
  }

  /// Miniatura de la fila, con el mismo estilo que las de Lista.
  Widget _thumb(String? path, {double size = 44}) {
    final theme = Theme.of(context);
    final cleaned = path?.trim();
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
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
              Icons.local_drink_outlined,
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

  Widget _viewSelector() => Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<_PlanView>(
          segments: const [
            ButtonSegment(
              value: _PlanView.montaje,
              icon: Icon(Icons.route_outlined),
              label: Text('Montaje'),
            ),
            ButtonSegment(
              value: _PlanView.lista,
              icon: Icon(Icons.checklist_rounded),
              label: Text('Lista'),
            ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _view = selection.first),
        ),
      );

  Widget _checklist(List<_CheckLine> lines) {
    final marked =
        lines.where((line) => _checked.contains(line.product.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: MutedText('$marked de ${lines.length} marcados')),
            if (marked > 0)
              TextButton.icon(
                onPressed: () => setState(_checked.clear),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Desmarcar todo'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _checklistRow(lines[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _checklistRow(_CheckLine line) {
    final theme = Theme.of(context);
    final product = line.product;
    final id = product.id;
    final checked = id != null && _checked.contains(id);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: id == null ? null : () => _toggleLine(id, !checked),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (value) => _toggleLine(id, value ?? false),
            ),
            _thumb(_productImage(product)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      color: checked ? muted : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.crateName} · ${product.unitsPerBox} uds/caja',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(
              label: '${line.units} uds',
              tone: checked ? AppTone.success : AppTone.info,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _floorSelector() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.layers_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            Text(
              'Consultar lista de otra planta',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<Floor>(
                value: _floor,
                isDense: true,
                borderRadius: BorderRadius.circular(AppRadii.md),
                items: [
                  for (final floor in Floor.values)
                    DropdownMenuItem(value: floor, child: Text(floor.label)),
                ],
                onChanged: (value) {
                  if (value != null) _selectFloor(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Column(
          children: [
            if (_canSwitchFloor)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.twoColumnContent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: _floorSelector(),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<PlanData>(
                future: _future,
                builder: (_, s) {
                  if (s.hasError) {
                    return AppErrorState(
                      title: 'No se pudo montar el plan.',
                      error: s.error!,
                      onRetry: _reload,
                    );
                  }
                  if (!s.hasData) {
                    return const AppLoadingState(label: 'Montando cajas…');
                  }
                  final plan = s.data!.plan;
                  final byType = s.data!.byType;
                  final hasSavedList = s.data!.hasSavedList;
                  final theme = Theme.of(context);
                  final crates = plan.crates;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.twoColumnContent,
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          if (plan.trips.isEmpty)
                            AppEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: !hasSavedList && _canSwitchFloor
                                  ? 'Sin lista para ${_floor!.label}'
                                  : 'No hay nada que montar',
                              message: !hasSavedList && _canSwitchFloor
                                  ? 'Ese día no hay consumo guardado para esta '
                                      'planta. Puedes consultar otra lista con el '
                                      'selector de arriba.'
                                  : 'La lista no tiene botellines pendientes de '
                                      'montaje.',
                            )
                          else
                            AppSectionCard(
                              icon: Icons.route_outlined,
                              title:
                                  '${plan.trips.length} viaje(s) · ${crates.length} cajas',
                              trailing: StatusPill(
                                label: '${plan.bottles} botellines',
                                tone: AppTone.info,
                                dense: true,
                              ),
                              children: [
                                Text(
                                  byType.entries
                                      .map((e) => '${e.key} ×${e.value}')
                                      .join('  ·  '),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: AppSpacing.md),
                          Card(
                            child: SwitchListTile(
                              title: const Text(
                                  'Cajas completas de un mismo producto'),
                              subtitle: const Text(
                                  'Si de un producto hay una caja entera o más, se prepara aparte sin mezclar.'),
                              value: _preferFull,
                              onChanged: _setPreferFull,
                            ),
                          ),
                          if (plan.trips.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            _viewSelector(),
                            const SizedBox(height: AppSpacing.md),
                            if (_view == _PlanView.lista)
                              _checklist(_loadLines(plan))
                            else
                              for (var i = 0; i < plan.trips.length; i++) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.xs,
                                    AppSpacing.lg,
                                    AppSpacing.xs,
                                    AppSpacing.sm,
                                  ),
                                  child: Text(
                                      'Viaje ${i + 1} · carro al ${plan.trips[i].percent}%',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      )),
                                ),
                                for (final c in plan.trips[i].crates)
                                  Card(
                                    child: ListTile(
                                      leading: Icon(c.dedicated
                                          ? Icons.inventory_2
                                          : Icons.shuffle),
                                      title: Text(
                                          'Caja ${c.name} · ${c.filled}/${c.capacity}${c.dedicated ? " · completa" : ""}'),
                                      subtitle: Text(c.lines
                                          .map((l) =>
                                              '${l.qty} × ${l.product.name}')
                                          .join('\n')),
                                      isThreeLine: c.lines.length > 1,
                                    ),
                                  ),
                              ],
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}
