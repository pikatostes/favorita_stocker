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
  final List<CrateLine> lines = [];
  Crate(this.name, this.capacity, this.cost);
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
/// 1. Solo se mezclan en una misma caja productos con el mismo tamaño,
///    altura, formato y unidades por caja. Por cada grupo se necesitan
///    ceil(botellines / unidades por caja) cajas, el mínimo posible.
///    Las cajas se llenan de una en una para que cada producto quede junto.
/// 2. Cada tipo de caja ocupa 1/N del carro (N = cajas de ese tipo por viaje:
///    5 de cerveza, 6 de cola, 5 de agua...). Se mezclan tipos en un viaje
///    sumando esas fracciones hasta completar 1 (first-fit decreasing).
class Planner {
  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
  static int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;

  static Plan build(List<Product> products, Map<int, int> qty) {
    final groups = <String, List<Product>>{};
    var bottles = 0;
    for (final p in products) {
      final q = qty[p.id] ?? 0;
      if (q <= 0) continue;
      bottles += q;
      groups
          .putIfAbsent(
              '${p.size}|${p.height}|${p.format}|${p.unitsPerBox}', () => [])
          .add(p);
    }
    if (groups.isEmpty) return Plan([], 0);

    final perTrip = {
      for (final e in groups.entries)
        e.key: e.value.map((p) => max(1, p.tripCapacity)).reduce(min),
    };
    var l = 1; // capacidad del carro en unidades enteras
    for (final c in perTrip.values) {
      l = _lcm(l, c);
    }

    // 1) Montar cajas
    final crates = <Crate>[];
    for (final e in groups.entries) {
      final g = [...e.value]..sort((a, b) => qty[b.id]!.compareTo(qty[a.id]!));
      final units = g.first.unitsPerBox;
      final name = g.first.crateName.isEmpty ? 'Caja' : g.first.crateName;
      final cost = l ~/ perTrip[e.key]!;
      Crate? cur;
      for (final p in g) {
        var left = qty[p.id]!;
        while (left > 0) {
          final c = cur ?? (cur = Crate(name, units, cost));
          final take = min(left, units - c.filled);
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
        if (x.load + c.cost <= l) {
          t = x;
          break;
        }
      }
      if (t == null) {
        t = Trip(l);
        trips.add(t);
      }
      t.crates.add(c);
      t.load += c.cost;
    }
    return Plan(trips, bottles);
  }
}
