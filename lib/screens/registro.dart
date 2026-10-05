import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
import '../widgets/category_tabs.dart';
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
  final Map<int, int> _qty = {}; // botellines gastados
  final Map<int, int> _boxes = {}; // cajas completas pedidas
  late Future<List<Product>> _future = Db.i.products();

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

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: Schedule.retentionLimit(),
        lastDate: DateTime.now());
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final hasLoose = _qty.values.any((q) => q > 0);
    final hasBoxes = _boxes.values.any((q) => q > 0);
    if (!hasLoose && !hasBoxes) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade algún botellín o caja a la lista')));
      return;
    }
    final qty = Map<int, int>.from(_qty);
    final boxes = Map<int, int>.from(_boxes);
    // Solo lo gastado cuenta como consumo. Las cajas completas pedidas son
    // reposición y no se guardan en el histórico (falsearían la previsión).
    if (hasLoose) await Db.i.saveNight(Schedule.fmt(_date), qty);
    if (!mounted) return;
    setState(() {
      _qty.clear();
      _boxes.clear();
    });
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlanScreen(qty: qty, fullBoxes: boxes)));
  }

  Widget _tile(Product p) {
    final q = _qty[p.id] ?? 0;
    final fb = _boxes[p.id] ?? 0;
    return ListTile(
      title: Text(p.name),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 16, color: fb > 0 ? Theme.of(context).colorScheme.primary : null),
          const SizedBox(width: 4),
          Text(fb == 0
              ? 'Cajas completas'
              : '$fb ${fb == 1 ? "caja completa" : "cajas completas"} (${fb * p.unitsPerBox} uds)'),
          IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.remove),
              onPressed:
                  fb > 0 ? () => setState(() => _boxes[p.id!] = fb - 1) : null),
          IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _boxes[p.id!] = fb + 1)),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: q > 0 ? () => setState(() => _qty[p.id!] = q - 1) : null),
        SizedBox(
            width: 32,
            child: Text('$q',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setState(() => _qty[p.id!] = q + 1)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lista de la noche'),
          actions: [
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat('EEE d MMM', 'es').format(_date)),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _save,
            icon: const Icon(Icons.inventory_2),
            label: const Text('Guardar y montar cajas')),
        body: FutureBuilder<List<Product>>(
          future: _future,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final products = s.data!;
            if (products.isEmpty) {
              return const Center(
                  child: Text('Primero añade productos en la pestaña Productos'));
            }
            return CategoryTabs(
              products: products,
              badge: (cat) {
                final n = products
                    .where((p) =>
                        p.category == cat &&
                        ((_qty[p.id] ?? 0) > 0 || (_boxes[p.id] ?? 0) > 0))
                    .length;
                return n == 0 ? '' : ' ($n)';
              },
              builder: (_, list) => ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: list.map(_tile).toList(),
              ),
            );
          },
        ),
      );
}
