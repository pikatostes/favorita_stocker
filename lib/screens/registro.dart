import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
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
  final Map<int, int> _qty = {};
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
    if (_qty.values.every((q) => q == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añade algún botellín a la lista')));
      return;
    }
    final qty = Map<int, int>.from(_qty);
    await Db.i.saveNight(Schedule.fmt(_date), qty);
    if (!mounted) return;
    setState(_qty.clear);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlanScreen(qty: qty)));
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
            if (s.data!.isEmpty) {
              return const Center(
                  child: Text('Primero añade productos en la pestaña Productos'));
            }
            final children = <Widget>[];
            String? last;
            for (final p in s.data!) {
              if (p.category != last) {
                last = p.category;
                children.add(Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(p.category,
                      style: Theme.of(context).textTheme.titleSmall),
                ));
              }
              final q = _qty[p.id] ?? 0;
              children.add(ListTile(
                title: Text(p.name),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: q > 0
                          ? () => setState(() => _qty[p.id!] = q - 1)
                          : null),
                  SizedBox(
                      width: 32,
                      child: Text('$q',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _qty[p.id!] = q + 1)),
                ]),
              ));
            }
            return ListView(
                padding: const EdgeInsets.only(bottom: 90), children: children);
          },
        ),
      );
}
