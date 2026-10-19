import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../planner.dart';

/// Resultado ya calculado del plan: evita volver a montar cajas y viajes en
/// cada reconstrucción de la pantalla.
class _PlanData {
  final Plan plan;
  final Map<String, int> byType; // nombre de caja -> nº de cajas
  _PlanData(this.plan, this.byType);
}

/// Adaptador para `compute`: monta cajas y viajes en un isolate de fondo para
/// no bloquear la UI. El mensaje es un record de datos planos (serializables).
_PlanData _buildPlanInBackground(
  ({
    List<Product> products,
    Map<int, int> qty,
    Map<int, int> fullBoxes,
    bool preferFull,
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
  return _PlanData(plan, byType);
}

/// Muestra cómo montar las cajas y en cuántos viajes llevarlas.
class PlanScreen extends StatefulWidget {
  final Map<int, int> qty; // productId -> botellines
  final Map<int, int> fullBoxes; // productId -> cajas completas pedidas
  final String title;
  const PlanScreen({
    super.key,
    required this.qty,
    this.fullBoxes = const {},
    this.title = 'Montar cajas',
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _preferFull = false;
  late Future<_PlanData> _future = _load();

  Future<_PlanData> _load() async {
    final products = await Db.i.products();
    return compute(_buildPlanInBackground, (
      products: products,
      qty: widget.qty,
      fullBoxes: widget.fullBoxes,
      preferFull: _preferFull,
    ));
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: FutureBuilder<_PlanData>(
          future: _future,
          builder: (_, s) {
            if (s.hasError) {
              return Center(
                  child: Text('No se pudo montar el plan: ${s.error}'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final plan = s.data!.plan;
            final byType = s.data!.byType;
            final theme = Theme.of(context);
            final crates = plan.crates;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (plan.trips.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay nada que montar.'))
                else
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${plan.trips.length} viaje(s) · ${crates.length} cajas · ${plan.bottles} botellines',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(byType.entries
                                .map((e) => '${e.key} ×${e.value}')
                                .join('  ·  ')),
                          ]),
                    ),
                  ),
                Card(
                  child: SwitchListTile(
                    title: const Text('Cajas completas de un mismo producto'),
                    subtitle: const Text(
                        'Si de un producto hay una caja entera o más, se prepara aparte sin mezclar.'),
                    value: _preferFull,
                    onChanged: _setPreferFull,
                  ),
                ),
                for (var i = 0; i < plan.trips.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text(
                        'Viaje ${i + 1} · carro al ${plan.trips[i].percent}%',
                        style: theme.textTheme.titleSmall),
                  ),
                  for (final c in plan.trips[i].crates)
                    Card(
                      child: ListTile(
                        leading: Icon(
                            c.dedicated ? Icons.inventory_2 : Icons.shuffle),
                        title: Text(
                            'Caja ${c.name} · ${c.filled}/${c.capacity}${c.dedicated ? " · completa" : ""}'),
                        subtitle: Text(c.lines
                            .map((l) => '${l.qty} × ${l.product.name}')
                            .join('\n')),
                        isThreeLine: c.lines.length > 1,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      );
}
