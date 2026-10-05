import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../planner.dart';

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
  late final Future<List<Product>> _products = Db.i.products();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: FutureBuilder<List<Product>>(
          future: _products,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final plan = Planner.build(s.data!, widget.qty,
                fullBoxes: widget.fullBoxes, preferFull: _preferFull);
            final theme = Theme.of(context);
            final crates = plan.crates;
            final byType = <String, int>{};
            for (final c in crates) {
              byType[c.name] = (byType[c.name] ?? 0) + 1;
            }
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
                    onChanged: (v) => setState(() => _preferFull = v),
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
