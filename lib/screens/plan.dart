import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_design.dart';
import '../db.dart';
import '../formats.dart';
import '../models.dart';
import '../planner.dart';
import '../shifts.dart';
import '../widgets/app_ui.dart';

/// Resultado ya calculado del plan: evita volver a montar cajas y viajes en
/// cada reconstrucción de la pantalla.
class _PlanData {
  final Plan plan;
  final Map<String, int> byType; // nombre de caja -> nº de cajas
  final bool hasSavedList;
  _PlanData(this.plan, this.byType, {this.hasSavedList = true});
}

/// Adaptador para `compute`: monta cajas y viajes en un isolate de fondo para
/// no bloquear la UI. El mensaje es un record de datos planos (serializables).
_PlanData _buildPlanInBackground(
  ({
    List<Product> products,
    Map<int, int> qty,
    Map<int, int> fullBoxes,
    bool preferFull,
    bool hasSavedList,
  }) input,
) {
  final plan = Planner.build(
    input.products,
    input.qty,
    fullBoxes: input.fullBoxes,
    preferFull: input.preferFull,
  );
  final byType = <String, int>{};
  for (final c in plan.crates) {
    byType[c.name] = (byType[c.name] ?? 0) + 1;
  }
  return _PlanData(plan, byType, hasSavedList: input.hasSavedList);
}

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
  late Future<_PlanData> _future = _load();

  bool get _canSwitchFloor => widget.date != null && _floor != null;

  String get _title {
    if (!_canSwitchFloor) return widget.title;
    return '${widget.title} · ${_floor!.label} · '
        '${formatShortDateIso(widget.date!)}';
  }

  /// La BD guarda el total en botellines; para montar cajas se separa en cajas
  /// completas y sueltos con las unidades por caja del producto.
  ({Map<int, int> qty, Map<int, int> fullBoxes}) _splitSaved(
    Map<int, int> saved,
    List<Product> products,
  ) {
    final qty = <int, int>{};
    final fullBoxes = <int, int>{};
    for (final product in products) {
      final id = product.id;
      if (id == null) continue;
      final total = saved[id] ?? 0;
      if (total <= 0) continue;
      final size = product.unitsPerBox < 1 ? 1 : product.unitsPerBox;
      final boxes = total ~/ size;
      final loose = total % size;
      if (boxes > 0) fullBoxes[id] = boxes;
      if (loose > 0) qty[id] = loose;
    }
    return (qty: qty, fullBoxes: fullBoxes);
  }

  Future<_PlanData> _load() async {
    // Las listas son históricas: un producto borrado después sigue formando
    // parte del montaje de esa noche.
    final products = await Db.i.products(includeDeleted: true);
    var qty = widget.qty;
    var fullBoxes = widget.fullBoxes;
    var hasSavedList = true;

    final date = widget.date;
    final floor = _floor;
    if (date != null && floor != null) {
      final saved = await Db.i.nightConsumption(date, floor);
      final split = _splitSaved(saved, products);
      qty = split.qty;
      fullBoxes = split.fullBoxes;
      hasSavedList = saved.isNotEmpty;
    }

    return compute(_buildPlanInBackground, (
      products: products,
      qty: qty,
      fullBoxes: fullBoxes,
      preferFull: _preferFull,
      hasSavedList: hasSavedList,
    ));
  }

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
      _future = _load();
    });
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
              child: FutureBuilder<_PlanData>(
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
                                  style: theme.textTheme.titleSmall?.copyWith(
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
                                      .map(
                                          (l) => '${l.qty} × ${l.product.name}')
                                      .join('\n')),
                                  isThreeLine: c.lines.length > 1,
                                ),
                              ),
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
