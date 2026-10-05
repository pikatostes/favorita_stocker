import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';

/// Excepciones al horario habitual (vie/sáb): festivos con apertura extra o
/// viernes/sábados cerrados.
class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});
  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  late Future<Map<String, SpecialDay>> _future = Db.i.specialDays();

  void _reload() {
    if (mounted) setState(() => _future = Db.i.specialDays());
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

  Future<void> _add() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: Schedule.retentionLimit(),
        lastDate: now.add(const Duration(days: 365)));
    if (date == null || !mounted) return;

    var open = !Schedule.openWeekdays.contains(date.weekday);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(DateFormat('EEEE d MMMM yyyy', 'es').format(date)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              title: Text(open ? 'Abierto' : 'Cerrado'),
              value: open,
              onChanged: (v) => setD(() => open = v),
            ),
            TextField(
                controller: note,
                decoration: const InputDecoration(
                    labelText: 'Motivo (Navidad, puente…)')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await Db.i.setSpecialDay(
          SpecialDay(Schedule.fmt(date), open: open, note: note.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Calendario')),
        floatingActionButton:
            FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
        body: FutureBuilder<Map<String, SpecialDay>>(
          future: _future,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final today = Schedule.fmt(DateTime.now());
            final all = s.data!.values.toList();
            final upcoming = all.where((d) => d.date.compareTo(today) >= 0).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            final past = all.where((d) => d.date.compareTo(today) < 0).toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            return ListView(children: [
              const ListTile(
                leading: Icon(Icons.schedule),
                title: Text('Horario habitual: viernes y sábado'),
                subtitle: Text('16:00–04:00 · máxima afluencia 21:00–04:00'),
              ),
              const Divider(),
              if (all.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Sin excepciones. Añade con + los festivos en que se abre o los viernes/sábados que se cierra.')),
              ...[...upcoming, ...past].map((d) => ListTile(
                    leading: Icon(d.open ? Icons.lock_open : Icons.lock_outline),
                    title: Text(DateFormat('EEE d MMM yyyy', 'es')
                        .format(DateTime.parse(d.date))),
                    subtitle: Text(
                        '${d.open ? "Abierto" : "Cerrado"}${d.note.isEmpty ? "" : " · ${d.note}"}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => Db.i.deleteSpecialDay(d.date),
                    ),
                  )),
            ]);
          },
        ),
      );
}
