import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../prediction.dart';
import '../schedule.dart';

class _View {
  final DateTime target;
  final bool open;
  final SpecialDay? special;
  final ForecastResult result;
  _View(this.target, this.open, this.special, this.result);
}

class PrevisionScreen extends StatefulWidget {
  const PrevisionScreen({super.key});
  @override
  State<PrevisionScreen> createState() => _PrevisionScreenState();
}

class _PrevisionScreenState extends State<PrevisionScreen> {
  DateTime? _target; // null = próximo día de apertura
  late Future<_View> _future = _load();

  Future<_View> _load() async {
    final special = await Db.i.specialDays();
    final t = _target ?? Schedule.nextOpen(DateTime.now(), special);
    return _View(t, Schedule.isOpen(t, special), special[Schedule.fmt(t)],
        await Predictor.forecast(t));
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
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

  Future<void> _pickDate(DateTime current) async {
    final d = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) {
      _target = d;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Previsión')),
        body: FutureBuilder<_View>(
          future: _future,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final v = s.data!;
            final r = v.result;
            return ListView(children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('EEEE d MMMM', 'es').format(v.target)),
                subtitle: Text(v.special?.note.isNotEmpty == true
                    ? v.special!.note
                    : 'Toca para cambiar de día'),
                onTap: () => _pickDate(v.target),
                trailing: _target == null
                    ? const Chip(label: Text('Próxima apertura'))
                    : TextButton(
                        onPressed: () {
                          _target = null;
                          _reload();
                        },
                        child: const Text('Próxima')),
              ),
              if (!v.open)
                MaterialBanner(
                  content:
                      const Text('Ese día normalmente el bar está cerrado.'),
                  actions: [
                    TextButton(
                        onPressed: () => Db.i.setSpecialDay(SpecialDay(
                            Schedule.fmt(v.target),
                            open: true)),
                        child: const Text('Marcar abierto')),
                  ],
                ),
              if (r.items.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no hay datos. Guarda algunas listas.'))
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Base: ${r.recentNights} noches recientes. '
                    '${r.seasonalYears == 0 ? "Sin histórico de años anteriores: todavía no se ajusta por temporada." : "Ajustado por temporada con ${r.seasonalYears} año(s) previo(s)."}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(
                      'Total: ${r.items.fold<int>(0, (a, f) => a + f.boxes)} cajas'),
                  trailing: FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlanScreen(
                                title: 'Cajas según previsión',
                                qty: {
                                  for (final f in r.items) f.product.id!: f.units
                                }))),
                    child: const Text('Montar cajas'),
                  ),
                ),
                const Divider(height: 1),
                ...r.items.map((f) => ListTile(
                      title: Text(f.product.name),
                      subtitle: Text('≈ ${f.units} uds · ${f.product.boxInfo}'),
                      trailing: Chip(label: Text('${f.boxes} cajas')),
                    )),
              ],
            ]);
          },
        ),
      );
}
