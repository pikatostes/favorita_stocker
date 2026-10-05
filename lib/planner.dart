import 'dart:math';
import 'models.dart';

class CrateLine {
  final Product product;
  final int qty;
  CrateLine(this.product, this.qty);
}

class Crate {
  final String name;
  final int capacity; // botellines que caben
  final int cost; // espacio que ocupa en el carro (en unidades enteras)
  final bool dedicated; // caja completa de un solo producto
  final List<CrateLine> lines = [];
  Crate(this.name, this.capacity, this.cost, {this.dedicated = false});
  int get filled => lines.fold(0, (s, l) => s + l.qty);
}

class Trip {
  final int capacity;
  final List<Crate> crates = [];
  int load = 0;
  Trip(this.capacity);
  int get percent => (load * 100 / capacity).round();
}

class Plan {
  final List<Trip> trips;
  final int bottles;
  Plan(this.trips, this.bottles);
  List<Crate> get crates => trips.expand((t) => t.crates).toList();
}

/// Monta las cajas y las reparte en viajes.
///
/// 0. Cajas completas de un solo producto: las que se piden expresamente
///    ([fullBoxes]) y, si [preferFull], las que salen de dividir cada
///    producto entre las unidades por caja. Van aparte, sin mezclar.
/// 1. El resto de botellines se mezcla: solo entre productos con el mismo
///    tamaño, altura, formato y unidades por caja, llenando las cajas de una
///    en una (mínimo de cajas posible para el sobrante).
/// 2. Cada tipo de caja ocupa 1/N del carro (N = cajas de ese tipo por viaje)
///    y se reparten en viajes sumando fracciones hasta 1 (first-fit decreasing).
class Planner {
  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
  static int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;

  static Plan build(
    List<Product> products,
    Map<int, int> qty, {
    Map<int, int> fullBoxes = const {},
    bool preferFull = false,
  }) {
    final groups = <String, List<Product>>{};
    final loose = <int, int>{}; // botellines a mezclar
    final boxes = <int, int>{}; // cajas completas
    var bottles = 0;

    for (final p in products) {
      var l = qty[p.id] ?? 0;
      var b = fullBoxes[p.id] ?? 0;
      if (preferFull && p.unitsPerBox > 0) {
        b += l ~/ p.unitsPerBox;
        l = l % p.unitsPerBox;
      }
      if (l <= 0 && b <= 0) continue;
      loose[p.id!] = l;
      boxes[p.id!] = b;
      bottles += l + b * p.unitsPerBox;
      groups
          .putIfAbsent(
              '${p.size}|${p.height}|${p.format}|${p.unitsPerBox}', () => [])
          .add(p);
    }
    if (groups.isEmpty) return Plan([], 0);

    final perTrip = <String, int>{
      for (final e in groups.entries)
        e.key: e.value.map((p) => max(1, p.tripCapacity)).reduce(min),
    };
    var carro = 1; // capacidad del carro en unidades enteras
    for (final c in perTrip.values) {
      carro = _lcm(carro, c);
    }

    final crates = <Crate>[];
    for (final e in groups.entries) {
      final g = e.value;
      final units = g.first.unitsPerBox;
      final name = g.first.crateName.isEmpty ? 'Caja' : g.first.crateName;
      final cost = carro ~/ perTrip[e.key]!;

      // 0) Cajas completas de un solo producto
      for (final p in g) {
        for (var i = 0; i < boxes[p.id]!; i++) {
          final c = Crate(name, units, cost, dedicated: true);
          c.lines.add(CrateLine(p, units));
          crates.add(c);
        }
      }

      // 1) Cajas mezcladas con el resto
      final mixed = g.where((p) => loose[p.id]! > 0).toList()
        ..sort((a, b) => loose[b.id]!.compareTo(loose[a.id]!));
      Crate? cur;
      for (final p in mixed) {
        var left = loose[p.id]!;
        while (left > 0) {
          final c = cur ?? (cur = Crate(name, units, cost));
          final take = min<int>(left, units - c.filled);
          c.lines.add(CrateLine(p, take));
          left -= take;
          if (c.filled >= units) {
            crates.add(c);
            cur = null;
          }
        }
      }
      if (cur != null) crates.add(cur);
    }

    // 2) Repartir en viajes (first-fit decreasing)
    crates.sort((a, b) {
      final c = b.cost.compareTo(a.cost);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    final trips = <Trip>[];
    for (final c in crates) {
      Trip? t;
      for (final x in trips) {
        if (x.load + c.cost <= carro) {
          t = x;
          break;
        }
      }
      if (t == null) {
        t = Trip(carro);
        trips.add(t);
      }
      t.crates.add(c);
      t.load += c.cost;
    }
    return Plan(trips, bottles);
  }
}
