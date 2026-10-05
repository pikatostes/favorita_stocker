import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../models.dart';
import '../schedule.dart';
import 'plan.dart';

class _CalData {
  final Map<String, Map<int, int>> nights; // fecha -> (producto -> botellines)
  final Map<String, SpecialDay> special;
  final Map<int, Product> products;
  _CalData(this.nights, this.special, this.products);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Calendario mensual: días trabajados (con lista guardada) resaltados.
/// Al tocar un día se ven sus detalles.
class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});
  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = Schedule.day(DateTime.now());
  late Future<_CalData> _future = _load();

  Future<_CalData> _load() async {
    final nights = await Db.i.nights();
    final special = await Db.i.specialDays();
    final products = await Db.i.products();
    return _CalData(nights, special, {for (final p in products) p.id!: p});
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

  void _goMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = Schedule.day(now);
    });
  }

  Future<void> _editSpecial(DateTime date, SpecialDay? current) async {
    var open = current?.open ?? !Schedule.openWeekdays.contains(date.weekday);
    final note = TextEditingController(text: current?.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(_cap(DateFormat('EEEE d MMMM yyyy', 'es').format(date))),
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

  // ---------- Cuadrícula del mes ----------

  Widget _cell(DateTime? day, _CalData d) {
    if (day == null) return const SizedBox(height: 44);
    final cs = Theme.of(context).colorScheme;
    final key = Schedule.fmt(day);
    final worked = d.nights.containsKey(key);
    final sp = d.special[key];
    final open = Schedule.isOpen(day, d.special);
    final today = day == Schedule.day(DateTime.now());
    final selected = day == _selected;

    Color? bg;
    var fg = cs.onSurface;
    Border? border;
    if (worked) {
      bg = cs.primary;
      fg = cs.onPrimary;
    } else if (sp != null && !sp.open) {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
    } else if (open) {
      border = Border.all(color: cs.primary, width: 1.5);
    }
    if (selected) border = Border.all(color: cs.onSurface, width: 2.5);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => _selected = day),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: bg, border: border),
              alignment: Alignment.center,
              child: Text('${day.day}',
                  style: TextStyle(
                      color: fg,
                      fontWeight: today ? FontWeight.w900 : FontWeight.normal,
                      decoration: today ? TextDecoration.underline : null)),
            ),
            if (sp != null)
              Positioned(
                  bottom: 1,
                  child: Icon(Icons.circle, size: 6, color: cs.tertiary)),
          ]),
        ),
      ),
    );
  }

  Widget _grid(_CalData d) {
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var i = 1; i <= days; i++) DateTime(_month.year, _month.month, i),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(children: [
      Row(children: [
        for (final w in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
          Expanded(
              child: Center(
                  child: Text(w, style: Theme.of(context).textTheme.labelMedium))),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < cells.length; r += 7)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: _cell(cells[r + c], d)),
        ]),
    ]);
  }

  Widget _legend() {
    final cs = Theme.of(context).colorScheme;
    Widget item(Widget mark, String text) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            mark,
            const SizedBox(width: 4),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ]),
        );
    Widget dot(Color? fill, {Color? border}) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: border == null ? null : Border.all(color: border, width: 1.5)));
    return Wrap(runSpacing: 4, children: [
      item(dot(cs.primary), 'Con lista'),
      item(dot(null, border: cs.primary), 'Abre'),
      item(dot(cs.errorContainer), 'Cerrado (excepción)'),
      item(Icon(Icons.circle, size: 8, color: cs.tertiary), 'Excepción'),
    ]);
  }

  // ---------- Detalle del día ----------

  Widget _details(_CalData d) {
    final theme = Theme.of(context);
    final key = Schedule.fmt(_selected);
    final qty = d.nights[key];
    final sp = d.special[key];
    final open = Schedule.isOpen(_selected, d.special);

    final byCat = <String, List<MapEntry<Product, int>>>{};
    var total = 0;
    if (qty != null) {
      final entries = <MapEntry<Product, int>>[];
      for (final e in qty.entries) {
        final p = d.products[e.key];
        if (p != null && e.value > 0) entries.add(MapEntry(p, e.value));
      }
      entries.sort((a, b) {
        final c = a.key.category.compareTo(b.key.category);
        return c != 0 ? c : a.key.name.compareTo(b.key.name);
      });
      for (final e in entries) {
        total += e.value;
        byCat.putIfAbsent(e.key.category, () => []).add(e);
      }
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_cap(DateFormat('EEEE d MMMM yyyy', 'es').format(_selected)),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            Chip(
                avatar: Icon(
                    qty != null
                        ? Icons.check_circle
                        : (open ? Icons.lock_open : Icons.lock_outline),
                    size: 18),
                label: Text(qty != null
                    ? 'Noche trabajada'
                    : (open ? 'Abre' : 'Cerrado'))),
            if (sp != null)
              Chip(
                  label: Text(sp.note.isEmpty
                      ? (sp.open ? 'Apertura extra' : 'Cierre extra')
                      : sp.note)),
          ]),
          const SizedBox(height: 8),
          if (qty == null)
            Text(
                open
                    ? 'Sin lista guardada para este día.'
                    : 'El bar no abre este día.',
                style: theme.textTheme.bodyMedium)
          else if (byCat.isEmpty)
            const Text('Noche trabajada sin consumo registrado.')
          else ...[
            Text('$total botellines gastados',
                style: theme.textTheme.titleSmall),
            for (final e in byCat.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(e.key,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              for (final it in e.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(it.key.name)),
                    Text('${it.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Ver montaje de cajas'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlanScreen(
                          qty: qty,
                          title: DateFormat('d MMM', 'es').format(_selected)))),
            ),
          ],
          const Divider(height: 24),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: Text(sp == null ? 'Marcar excepción' : 'Editar excepción'),
              onPressed: () => _editSpecial(_selected, sp),
            ),
            if (sp != null)
              TextButton(
                  onPressed: () => Db.i.deleteSpecialDay(key),
                  child: const Text('Quitar excepción')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Calendario'),
          actions: [
            TextButton(onPressed: _goToday, child: const Text('Hoy')),
          ],
        ),
        body: FutureBuilder<_CalData>(
          future: _future,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final d = s.data!;
            return ListView(padding: const EdgeInsets.all(12), children: [
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _goMonth(-1)),
                Expanded(
                  child: Center(
                    child: Text(
                        _cap(DateFormat('MMMM yyyy', 'es').format(_month)),
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _goMonth(1)),
              ]),
              _grid(d),
              const SizedBox(height: 8),
              _legend(),
              _details(d),
              const SizedBox(height: 24),
            ]);
          },
        ),
      );
}
