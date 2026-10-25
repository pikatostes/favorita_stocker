import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

/// Una línea del resumen: lo pedido de un producto, separado en cajas completas
/// y botellines sueltos tal y como se introdujo en la lista.
class LineaPedido {
  final Product product;
  final int boxes;
  final int loose;

  const LineaPedido(this.product, {required this.boxes, required this.loose});

  /// Total en botellines (cajas × unidades por caja + sueltos).
  int get units => boxes * product.unitsPerBox + loose;
}

/// Pantalla intermedia entre la lista de consumo y el montaje de cajas.
///
/// Muestra el resumen de lo pedido para que el usuario lo revise y lo confirme
/// otra vez antes de guardarlo. Devuelve `true` al confirmar y `false` (o
/// `null` si se cierra) al volver a editar.
class ConfirmarListaScreen extends StatelessWidget {
  final DateTime date;
  final List<LineaPedido> lines;

  const ConfirmarListaScreen({
    super.key,
    required this.date,
    required this.lines,
  });

  /// "1 caja" / "2 cajas", para no mostrar textos del tipo "1 cajas".
  static String _plural(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';

  String _detail(LineaPedido line) {
    final unit = line.product.unitsPerBox;
    if (unit <= 1) return 'Botellín suelto';
    final parts = <String>[
      if (line.boxes > 0) _plural(line.boxes, 'caja', 'cajas'),
      if (line.loose > 0) _plural(line.loose, 'suelto', 'sueltos'),
    ];
    return '${parts.join(' · ')} · $unit uds/caja';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUnits = lines.fold<int>(0, (total, l) => total + l.units);
    final totalBoxes = lines.fold<int>(0, (total, l) => total + l.boxes);
    final totalLoose = lines.fold<int>(0, (total, l) => total + l.loose);

    // Se conserva el orden de la lista original; solo se agrupa por categoría
    // para que el resumen sea más fácil de revisar.
    final byCategory = <String, List<LineaPedido>>{};
    for (final line in lines) {
      byCategory.putIfAbsent(line.product.category, () => []).add(line);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar lista')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumen del pedido', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es')
                      .format(date)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Stat(label: 'Productos', value: '${lines.length}'),
                      _Stat(label: 'Botellines', value: '$totalUnits'),
                      _Stat(label: 'Cajas', value: '$totalBoxes'),
                      _Stat(label: 'Sueltos', value: '$totalLoose'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final entry in byCategory.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(entry.key, style: theme.textTheme.titleSmall),
            ),
            Card(
              child: Column(
                children: [
                  for (final line in entry.value)
                    ListTile(
                      leading: const Icon(Icons.local_drink_outlined),
                      title: Text(line.product.name),
                      subtitle: Text(_detail(line)),
                      trailing: Text(
                        '${line.units} uds',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.fact_check_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Confirmas que la lista es correcta?',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Al confirmar se guardará la lista de la noche '
                    'seleccionada. Si ya había una guardada, se sustituirá.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      lines.isEmpty ? null : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar pedido'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Volver a editar la lista'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato suelto del resumen (etiqueta pequeña encima del valor).
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
