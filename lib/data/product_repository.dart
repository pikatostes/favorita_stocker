import 'package:flutter/foundation.dart';

import '../db.dart';
import '../models.dart';
import '../planner.dart';
import '../shifts.dart';

/// Resultado ya calculado de un plan de montaje.
///
/// [byType] cuenta cuántas cajas hay de cada tipo y [hasSavedList] indica si el
/// día consultado tenía consumo guardado (frente a una lista sin montaje).
class PlanData {
  final Plan plan;
  final Map<String, int> byType; // nombre de caja -> nº de cajas
  final bool hasSavedList;

  const PlanData(this.plan, this.byType, {this.hasSavedList = true});
}

/// Acceso a los productos del catálogo y a los datos derivados que necesitan
/// las pantallas.
///
/// Centraliza las consultas para que las pantallas no dependan directamente de
/// [Db] y sea más fácil cambiar el origen de datos.
class ProductRepository {
  ProductRepository._();
  static final ProductRepository i = ProductRepository._();

  /// Productos del catálogo, ordenados por categoría y nombre.
  ///
  /// [includeDeleted] incluye los productos con borrado lógico; es necesario
  /// para reconstruir listas de montaje antiguas, donde un producto puede
  /// haberse borrado después de la noche que se está consultando.
  Future<List<Product>> products({bool includeDeleted = false}) =>
      Db.i.products(includeDeleted: includeDeleted);

  /// Carga y calcula el plan de montaje de una noche.
  ///
  /// Si se indican [date] y [floor], se usa el consumo guardado de esa noche y
  /// planta (partiéndolo en cajas completas y botellines sueltos). Si no, se
  /// monta el pedido recibido en [qty] y [fullBoxes]. El cálculo pesado se
  /// delega a un isolate para no bloquear la interfaz.
  Future<PlanData> loadPlan({
    required Map<int, int> qty,
    Map<int, int> fullBoxes = const {},
    bool preferFull = false,
    String? date,
    Floor? floor,
  }) async {
    // Las listas son históricas: un producto borrado después sigue formando
    // parte del montaje de esa noche.
    final products = await this.products(includeDeleted: true);
    var planQty = qty;
    var planFullBoxes = fullBoxes;
    var hasSavedList = true;

    if (date != null && floor != null) {
      final saved = await Db.i.nightConsumption(date, floor);
      final split = _splitSaved(saved, products);
      planQty = split.qty;
      planFullBoxes = split.fullBoxes;
      hasSavedList = saved.isNotEmpty;
    }

    return compute(_buildPlanInBackground, (
      products: products,
      qty: planQty,
      fullBoxes: planFullBoxes,
      preferFull: preferFull,
      hasSavedList: hasSavedList,
    ));
  }
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

/// Adaptador para `compute`: monta cajas y viajes en un isolate de fondo para
/// no bloquear la UI. El mensaje es un record de datos planos (serializables).
PlanData _buildPlanInBackground(
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
  return PlanData(plan, byType, hasSavedList: input.hasSavedList);
}
